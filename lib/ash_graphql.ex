defmodule AshGraphql do
  @moduledoc """
  AshGraphql is a GraphQL extension for the Ash framework.

  For more information, see the [getting started guide](/documentation/tutorials/getting-started-with-graphql.md)
  """

  defmacro mutation(do: block) do
    empty? = !match?({:__block__, _, []}, block)

    quote bind_quoted: [empty?: empty?, block: Macro.escape(block)] do
      require Absinthe.Schema

      if empty? ||
           Enum.any?(
             @ash_resources,
             fn resource ->
               !Enum.empty?(AshGraphql.Resource.Info.mutations(resource))
             end
           ) do
        Code.eval_quoted(
          quote do
            Absinthe.Schema.mutation do
              unquote(block)
            end
          end,
          [],
          __ENV__
        )
      end
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [
            domains: opts[:domains],
            domain: opts[:domain],
            action_middleware: opts[:action_middleware] || [],
            define_relay_types?: Keyword.get(opts, :define_relay_types?, true),
            relay_ids?: Keyword.get(opts, :relay_ids?, false)
          ],
          generated: true do
      require Ash.Domain.Info

      import Absinthe.Schema,
        except: [
          mutation: 1
        ]

      import AshGraphql,
        only: [
          mutation: 1
        ]

      domains =
        domain
        |> List.wrap()
        |> Kernel.++(List.wrap(domains))

      domains =
        domains
        |> Enum.map(fn
          {domain, registry} ->
            IO.warn("""
            It is no longer required to list the registry along with a domain when using `AshGraphql`

               use AshGraphql, domains: [{My.App.Domain, My.App.Registry}]

            Can now be stated simply as

               use AshGraphql, domains: [My.App.Domain]
            """)

            domain

          domain ->
            domain
        end)
        |> Enum.map(fn domain -> {domain, Ash.Domain.Info.resources(domain), false} end)
        |> List.update_at(0, fn {domain, resources, _} -> {domain, resources, true} end)

      @ash_resources Enum.flat_map(domains, &elem(&1, 1))
      ash_resources = @ash_resources

      schema = __MODULE__
      schema_env = __ENV__

      for resource <- ash_resources do
        resource
        |> AshGraphql.Resource.get_auto_unions()
        |> Enum.concat(resource |> AshGraphql.Resource.global_unions() |> Enum.map(&elem(&1, 1)))
        |> Enum.map(fn attribute ->
          if Ash.Type.NewType.new_type?(attribute.type) do
            cond do
              function_exported?(attribute.type, :graphql_type, 0) ->
                attribute.type.graphql_type()

              function_exported?(attribute.type, :graphql_type, 1) ->
                attribute.type.graphql_type(attribute.constraints)

              true ->
                AshGraphql.Resource.atom_enum_type(resource, attribute.name)
            end
          else
            AshGraphql.Resource.atom_enum_type(resource, attribute.name)
          end
        end)
        |> Enum.uniq()
        |> Enum.each(fn type_name ->
          # sobelow_skip ["DOS.BinToAtom"]
          def unquote(:"resolve_gql_union_#{type_name}")(%Ash.Union{type: type}, _) do
            # sobelow_skip ["DOS.BinToAtom"]
            :"#{unquote(type_name)}_#{type}"
          end

          def unquote(:"resolve_gql_union_#{type_name}")(value, _) do
            value.__union_type__
          end
        end)
      end

      for {domain, resources, first?} <- domains do
        defmodule Module.concat(domain, AshTypes) do
          @moduledoc false
          alias Absinthe.{Blueprint, Phase, Pipeline}

          def pipeline(pipeline) do
            Pipeline.insert_before(
              pipeline,
              Absinthe.Phase.Schema.ApplyDeclaration,
              __MODULE__
            )
          end

          @dialyzer {:nowarn_function, {:run, 2}}
          def run(blueprint, _opts) do
            domain = unquote(domain)
            action_middleware = unquote(action_middleware)

            domain_queries =
              AshGraphql.Domain.queries(
                domain,
                unquote(resources),
                action_middleware,
                __MODULE__,
                unquote(relay_ids?)
              )

            relay_queries =
              if unquote(first?) and unquote(define_relay_types?) and unquote(relay_ids?) do
                domains_with_resources = unquote(Enum.map(domains, &{elem(&1, 0), elem(&1, 1)}))
                AshGraphql.relay_queries(domains_with_resources, unquote(schema), __ENV__)
              else
                []
              end

            blueprint_with_queries =
              (relay_queries ++ domain_queries)
              |> Enum.reduce(blueprint, fn query, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootQueryType", query)
              end)

            blueprint_with_mutations =
              domain
              |> AshGraphql.Domain.mutations(
                unquote(resources),
                action_middleware,
                __MODULE__,
                unquote(relay_ids?)
              )
              |> Enum.reduce(blueprint_with_queries, fn mutation, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootMutationType", mutation)
              end)

            type_definitions =
              if unquote(first?) do
                domains = unquote(Enum.map(domains, &elem(&1, 0)))

                embedded_types =
                  AshGraphql.get_embedded_types(
                    unquote(ash_resources),
                    unquote(schema),
                    unquote(relay_ids?)
                  )

                global_enums =
                  AshGraphql.global_enums(unquote(ash_resources), unquote(schema), __ENV__)

                global_unions =
                  AshGraphql.global_unions(unquote(ash_resources), unquote(schema), __ENV__)

                Enum.uniq_by(
                  AshGraphql.Domain.global_type_definitions(unquote(schema), __ENV__) ++
                    AshGraphql.Domain.type_definitions(
                      domain,
                      unquote(resources),
                      unquote(schema),
                      __ENV__,
                      true,
                      unquote(define_relay_types?),
                      unquote(relay_ids?)
                    ) ++
                    global_enums ++
                    global_unions ++
                    embedded_types,
                  & &1.identifier
                )
              else
                AshGraphql.Domain.type_definitions(
                  domain,
                  unquote(resources),
                  unquote(schema),
                  __ENV__,
                  false,
                  false,
                  unquote(relay_ids?)
                )
              end

            new_defs =
              List.update_at(blueprint_with_mutations.schema_definitions, 0, fn schema_def ->
                %{
                  schema_def
                  | type_definitions: schema_def.type_definitions ++ type_definitions
                }
              end)

            {:ok, %{blueprint_with_mutations | schema_definitions: new_defs}}
          end
        end

        if first? do
          import_types(Absinthe.Type.Custom)
          import_types(AshGraphql.Types.JSON)
          import_types(AshGraphql.Types.JSONString)
        end

        @pipeline_modifier Module.concat(domain, AshTypes)
      end
    end
  end

  def global_enums(resources, schema, env) do
    resources
    |> Enum.flat_map(&all_attributes_and_arguments/1)
    |> only_enum_types()
    |> Enum.uniq()
    |> Enum.map(fn type ->
      {name, identifier} =
        case type do
          Ash.Type.DurationName ->
            {"DurationName", :duration_name}

          type ->
            graphql_type = type.graphql_type()
            {graphql_type |> to_string() |> Macro.camelize(), graphql_type}
        end

      %Absinthe.Blueprint.Schema.EnumTypeDefinition{
        module: schema,
        name: name,
        values:
          Enum.map(type.values(), fn value ->
            name =
              if function_exported?(type, :graphql_rename_value, 1) do
                type.graphql_rename_value(value)
              else
                value
              end

            description =
              if function_exported?(type, :graphql_describe_enum_value, 1) do
                type.graphql_describe_enum_value(value)
              else
                enum_type_description(type, value)
              end

            %Absinthe.Blueprint.Schema.EnumValueDefinition{
              module: schema,
              identifier: value,
              __reference__: AshGraphql.Resource.ref(env),
              description: description,
              name: String.upcase(to_string(name)),
              value: value
            }
          end),
        identifier: identifier,
        __reference__: AshGraphql.Resource.ref(env)
      }
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  defp enum_type_description(type, value) do
    if Spark.implements_behaviour?(type, Ash.Type.Enum) do
      type.description(value)
    else
      nil
    end
  end

  def global_unions(resources, schema, env) do
    resources
    |> Enum.flat_map(fn resource ->
      resource
      |> AshGraphql.Resource.global_unions()
      |> Enum.flat_map(fn {type, attribute} ->
        type_name =
          if function_exported?(type, :graphql_type, 0) do
            type.graphql_type()
          else
            type.graphql_type(attribute.constraints)
          end

        input_type_name =
          cond do
            function_exported?(type, :graphql_input_type, 0) ->
              type.graphql_input_type()

            function_exported?(type, :graphql_input_type, 1) ->
              type.graphql_input_type(attribute.constraints)

            true ->
              "#{type_name}_input"
          end

        AshGraphql.Resource.union_type_definitions(
          resource,
          attribute,
          type_name,
          schema,
          env,
          input_type_name
        )
      end)
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  @doc false
  def all_attributes_and_arguments(
        resource,
        already_checked \\ [],
        nested? \\ true,
        return_new_checked? \\ false
      ) do
    if resource in already_checked do
      if return_new_checked? do
        {[], already_checked}
      else
        []
      end
    else
      already_checked = [resource | already_checked]

      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.concat(all_arguments(resource))
      |> Enum.concat(Ash.Resource.Info.calculations(resource))
      |> Enum.concat(
        resource
        |> Ash.Resource.Info.actions()
        |> Enum.filter(&(&1.type == :action))
        |> Enum.map(fn action ->
          %{type: action.returns, constraints: action.constraints, name: action.name}
        end)
      )
      |> Enum.reduce({[], already_checked}, fn %{type: type} = attr, {acc, already_checked} ->
        if nested? do
          constraints = Map.get(attr, :constraints, [])
          {nested, already_checked} = nested_attrs(type, constraints, already_checked)
          {[attr | nested] ++ acc, already_checked}
        else
          {[attr | acc], already_checked}
        end
      end)
      |> then(fn {attrs, checked} ->
        attrs = Enum.filter(attrs, &AshGraphql.Resource.Info.show_field?(resource, &1.name))

        if return_new_checked? do
          {attrs, checked}
        else
          attrs
        end
      end)
    end
  end

  def relay_queries(domains_with_resources, schema, env) do
    type_to_domain_and_resource_map =
      domains_with_resources
      |> Enum.flat_map(fn {domain, resources} ->
        resources
        |> Enum.flat_map(fn resource ->
          type = AshGraphql.Resource.Info.type(resource)

          if type do
            [{type, {domain, resource}}]
          else
            []
          end
        end)
      end)
      |> Enum.into(%{})

    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        name: "node",
        identifier: :node,
        arguments: [
          %Absinthe.Blueprint.Schema.InputValueDefinition{
            name: "id",
            identifier: :id,
            type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: :id
            },
            description: "The Node unique identifier",
            __reference__: AshGraphql.Resource.ref(env)
          }
        ],
        middleware: [
          {{AshGraphql.Graphql.Resolver, :resolve_node}, type_to_domain_and_resource_map}
        ],
        complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
        module: schema,
        description: "Retrieves a Node from its global id",
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :node},
        __reference__: AshGraphql.Resource.ref(__ENV__)
      }
    ]
  end

  defp nested_attrs({:array, type}, constraints, already_checked) do
    nested_attrs(type, constraints[:items] || [], already_checked)
  end

  defp nested_attrs(Ash.Type.Union, constraints, already_checked) do
    Enum.reduce(
      constraints[:types] || [],
      {[], already_checked},
      fn {_, config}, {attrs, already_checked} ->
        case config[:type] do
          {:array, type} ->
            {new, already_checked} =
              nested_attrs(type, config[:constraints][:items] || [], already_checked)

            {attrs ++ new, already_checked}

          type ->
            {new, already_checked} =
              nested_attrs(type, config[:constraints] || [], already_checked)

            {attrs ++ new, already_checked}
        end
      end
    )
  end

  defp nested_attrs(type, constraints, already_checked) do
    cond do
      AshGraphql.Resource.embedded?(type) ->
        type
        |> unwrap_type()
        |> all_attributes_and_arguments(already_checked, true, true)

      Ash.Type.NewType.new_type?(type) ->
        constraints = Ash.Type.NewType.constraints(type, constraints)
        type = Ash.Type.NewType.subtype_of(type)
        nested_attrs(type, constraints, already_checked)

      true ->
        {[], already_checked}
    end
  end

  def get_embed(type) do
    if Ash.Type.NewType.new_type?(type) do
      Ash.Type.NewType.subtype_of(type)
    else
      type
    end
  end

  @doc false
  def only_union_types(attributes) do
    Enum.flat_map(attributes, fn attribute ->
      attribute
      |> only_union_type()
      |> List.wrap()
    end)
  end

  defp only_union_type(%{type: {:array, type}, constraints: constraints} = attribute) do
    only_union_type(%{attribute | type: type, constraints: constraints[:items] || []})
  end

  defp only_union_type(attribute) do
    this_union_type =
      case union_type(attribute.type) do
        nil ->
          nil

        type ->
          {type, attribute}
      end

    attribute = %{
      attribute
      | type:
          attribute.type
          |> unwrap_type()
          |> Ash.Type.NewType.subtype_of(),
        constraints: Ash.Type.NewType.constraints(attribute.type, attribute.constraints)
    }

    case unwrap_type(attribute.type) do
      Ash.Type.Union ->
        attribute.constraints[:types]
        |> Kernel.||([])
        |> Enum.flat_map(fn {_name, config} ->
          case union_type(config[:type]) do
            nil ->
              []

            type ->
              [{type, attribute}]
          end
        end)

      type ->
        case union_type(type) do
          nil ->
            []

          type ->
            [{type, attribute}]
        end
    end
    |> Enum.concat(List.wrap(this_union_type))
  end

  defp only_enum_types(attributes) do
    Enum.flat_map(attributes, fn attribute ->
      attribute = %{
        type:
          attribute.type
          |> unwrap_type()
          |> Ash.Type.NewType.subtype_of(),
        constraints: Ash.Type.NewType.constraints(attribute.type, attribute.constraints)
      }

      case unwrap_type(attribute.type) do
        Ash.Type.Union ->
          Enum.flat_map(attribute.constraints[:types] || [], fn {_name, config} ->
            case enum_type(config[:type]) do
              nil ->
                []

              type ->
                [type]
            end
          end)

        type ->
          case enum_type(type) do
            nil ->
              []

            type ->
              [type]
          end
      end
    end)
  end

  defp union_type({:array, type}) do
    union_type(type)
  end

  defp union_type(type) do
    if Ash.Type.NewType.new_type?(type) &&
         Ash.Type.NewType.subtype_of(type) == Ash.Type.Union &&
         (function_exported?(type, :graphql_type, 0) ||
            function_exported?(type, :graphql_type, 1)) do
      type
    end
  end

  # sobelow_skip ["DOS.BinToAtom"]
  def get_embedded_types(all_resources, schema, relay_ids?) do
    all_resources
    |> Enum.flat_map(fn resource ->
      resource
      |> all_attributes_and_arguments()
      |> Enum.map(&{resource, &1})
    end)
    |> Enum.flat_map(fn
      {source_resource, attribute} ->
        {type, constraints} =
          case attribute.type do
            {:array, type} ->
              {type, attribute.constraints[:items] || []}

            type ->
              {type, attribute.constraints}
          end

        attribute = %{
          attribute
          | type:
              type
              |> Ash.Type.NewType.subtype_of(),
            constraints: Ash.Type.NewType.constraints(type, constraints)
        }

        case attribute.type do
          Ash.Type.Map ->
            if attribute.constraints[:fields] do
              {source_resource, attribute}
            end

            []

          Ash.Type.Union ->
            attribute.constraints[:types]
            |> Kernel.||([])
            |> Enum.flat_map(fn {name, config} ->
              if AshGraphql.Resource.embedded?(config[:type]) do
                [
                  {source_resource,
                   %{
                     attribute
                     | type: config[:type],
                       constraints: config[:constraints],
                       name: :"#{attribute.name}_#{name}"
                   }}
                ]
              else
                []
              end
            end)

          other ->
            if AshGraphql.Resource.embedded?(other) do
              [{source_resource, attribute}]
            else
              []
            end
        end
    end)
    |> Enum.map(fn {source_resource, attribute} ->
      type = unwrap_type(attribute.type)
      Code.ensure_compiled!(type)
      {source_resource, attribute, type}
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded} ->
      [{source_resource, attribute, embedded}] ++ get_nested_embedded_types(embedded)
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded_type} ->
      if AshGraphql.Resource.Info.type(embedded_type) do
        [
          AshGraphql.Resource.type_definition(
            embedded_type,
            Module.concat(embedded_type, ShadowDomain),
            schema,
            relay_ids?
          ),
          AshGraphql.Resource.embedded_type_input(
            source_resource,
            attribute,
            embedded_type,
            schema
          )
        ] ++
          AshGraphql.Resource.enum_definitions(embedded_type, schema, __ENV__) ++
          AshGraphql.Resource.map_definitions(embedded_type, schema, __ENV__)
      else
        []
      end
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  defp all_arguments(resource) do
    action_arguments =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.filter(&used_in_gql?(resource, &1))
      |> Enum.flat_map(& &1.arguments)

    calculation_arguments =
      resource
      |> Ash.Resource.Info.public_calculations()
      |> Enum.flat_map(& &1.arguments)

    action_arguments ++ calculation_arguments
  end

  defp used_in_gql?(resource, %{name: name}) do
    if Ash.Resource.Info.embedded?(resource) do
      # We should actually check if any resource refers to this action for this
      true
    else
      mutations = AshGraphql.Resource.Info.mutations(resource)
      queries = AshGraphql.Resource.Info.queries(resource)

      Enum.any?(mutations, fn mutation ->
        mutation.action == name || Map.get(mutation, :read_action) == name
      end) || Enum.any?(queries, &(&1.action == name))
    end
  end

  defp enum_type({:array, type}), do: enum_type(type)

  defp enum_type(type) do
    if is_atom(type) && ensure_compiled?(type) && function_exported?(type, :values, 0) &&
         (function_exported?(type, :graphql_type, 0) || function_exported?(type, :graphql_type, 1)) do
      type
    end
  end

  defp ensure_compiled?(type) do
    Code.ensure_compiled!(type)
  rescue
    _ ->
      false
  end

  defp unwrap_type({:array, type}), do: unwrap_type(type)
  defp unwrap_type(type), do: type

  defp get_nested_embedded_types(embedded_type) do
    embedded_type
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&AshGraphql.Resource.embedded?(&1.type))
    |> Enum.map(fn attribute ->
      {attribute, unwrap_type(attribute.type)}
    end)
    |> Enum.flat_map(fn {attribute, embedded} ->
      [{embedded_type, attribute, embedded}] ++ get_nested_embedded_types(embedded)
    end)
  end

  @deprecated "add_context is no longer necessary"
  def add_context(ctx, _domains, _options \\ []) do
    ctx
  end
end
