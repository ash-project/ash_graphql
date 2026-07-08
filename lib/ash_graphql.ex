# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql do
  @moduledoc """
  AshGraphql is a GraphQL extension for the Ash framework.

  For more information, see the [getting started guide](/documentation/tutorials/getting-started-with-graphql.md)
  """

  @doc false
  defmacro mutation(do: block) do
    empty? = !match?({:__block__, _, []}, block)

    quote bind_quoted: [empty?: empty?, block: Macro.escape(block)], location: :keep do
      require Absinthe.Schema

      if empty? ||
           Enum.any?(
             @ash_resources,
             fn resource ->
               !Enum.empty?(
                 AshGraphql.Resource.Info.mutations(resource, @all_domains, @ash_graphql_labels)
               )
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

  defmacro subscription(do: block) do
    empty? = !match?({:__block__, _, []}, block)

    quote bind_quoted: [empty?: empty?, block: Macro.escape(block)], location: :keep do
      require Absinthe.Schema

      if empty? ||
           Enum.any?(
             @ash_resources,
             fn resource ->
               !Enum.empty?(AshGraphql.Resource.Info.subscriptions(resource, @all_domains))
             end
           ) do
        Code.eval_quoted(
          quote do
            Absinthe.Schema.subscription do
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
    auto_import_types =
      if Keyword.get(opts, :auto_import_absinthe_types?, true) do
        quote do
          import_types(Absinthe.Type.Custom)
          import_types(AshGraphql.Types.JSON)
          import_types(AshGraphql.Types.JSONString)
        end
      end

    quote bind_quoted: [
            domains: opts[:domains],
            domain: opts[:domain],
            generate_sdl_file: opts[:generate_sdl_file],
            auto_generate_sdl_file?: opts[:auto_generate_sdl_file?],
            action_middleware: opts[:action_middleware] || [],
            define_relay_types?: Keyword.get(opts, :define_relay_types?, true),
            relay_ids?: Keyword.get(opts, :relay_ids?, false),
            response_metadata: opts[:response_metadata],
            default_types: opts[:default_types] || [],
            default_input_types: opts[:default_input_types] || [],
            labels: opts[:labels],
            labels_specified?: Keyword.has_key?(opts, :labels),
            auto_import_types: Macro.escape(auto_import_types)
          ],
          location: :keep,
          generated: true do
      require Ash.Domain.Info

      labels =
        if labels_specified? do
          List.wrap(labels)
        end

      AshGraphql.validate_response_metadata!(response_metadata)
      AshGraphql.validate_default_types!(default_types, :default_types)
      AshGraphql.validate_default_types!(default_input_types, :default_input_types)

      import Absinthe.Schema,
        except: [
          mutation: 1,
          subscription: 1
        ]

      import AshGraphql,
        only: [
          mutation: 1,
          subscription: 1
        ]

      @after_compile AshGraphql.Codegen

      domains =
        domain
        |> List.wrap()
        |> Kernel.++(List.wrap(domains))
        |> Enum.uniq()

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
        |> Enum.reduce({[], []}, fn {domain, resources, first?}, {acc, seen_resources} ->
          resources = Enum.reject(resources, &(&1 in seen_resources))

          {[{domain, resources, first?} | acc], seen_resources ++ resources}
        end)
        |> elem(0)
        |> Enum.reverse()
        |> List.update_at(0, fn {domain, resources, _} -> {domain, resources, true} end)

      @generate_sdl_file generate_sdl_file
      @auto_generate_sdl_file? auto_generate_sdl_file?

      @doc false
      def generate_sdl_file do
        @generate_sdl_file
      end

      @doc false
      def auto_generate_sdl_file? do
        @auto_generate_sdl_file?
      end

      @response_metadata response_metadata
      @ash_graphql_labels labels
      @default_types default_types
      @default_input_types default_input_types

      @doc false
      def response_metadata do
        @response_metadata
      end

      @doc false
      def ash_graphql_labels do
        @ash_graphql_labels
      end

      @doc false
      def default_types, do: @default_types

      @doc false
      def default_input_types, do: @default_input_types

      @doc false
      def ash_graphql_schema?, do: true

      @ash_resources Enum.flat_map(domains, &elem(&1, 1))
      ash_resources = @ash_resources
      @all_domains Enum.map(domains, &elem(&1, 0))

      Enum.each(ash_resources, &Code.ensure_compiled!/1)

      AshGraphql.validate_labels!(
        labels,
        ash_resources,
        Enum.map(domains, &elem(&1, 0))
      )

      AshGraphql.validate_domains_for_relationships!(
        ash_resources,
        Enum.map(domains, &elem(&1, 0))
      )

      schema = __MODULE__
      schema_env = __ENV__
      last_domain = domains |> List.last() |> elem(0)

      for resource <- ash_resources do
        resource
        |> AshGraphql.Resource.global_unions(Enum.map(domains, &elem(&1, 0)))
        |> Enum.map(&elem(&1, 1))
        |> Enum.map(fn attribute ->
          if function_exported?(attribute.type, :graphql_type, 1) do
            attribute.type.graphql_type(attribute.constraints)
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
        last? = domain == last_domain

        defmodule Module.concat([__MODULE__, domain, AshTypes]) do
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

            all_domains = unquote(Enum.map(domains, &elem(&1, 0)))
            labels = unquote(labels)

            domain_queries =
              AshGraphql.Domain.queries(
                domain,
                all_domains,
                unquote(resources),
                action_middleware,
                unquote(schema),
                unquote(relay_ids?),
                labels
              )

            relay_queries =
              if unquote(first?) and unquote(define_relay_types?) and unquote(relay_ids?) do
                domains_with_resources = unquote(Enum.map(domains, &{elem(&1, 0), elem(&1, 1)}))

                AshGraphql.relay_queries(
                  domains_with_resources,
                  all_domains,
                  unquote(schema),
                  __ENV__,
                  labels
                )
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
                all_domains,
                unquote(resources),
                action_middleware,
                unquote(schema),
                unquote(relay_ids?),
                labels
              )
              |> Enum.reduce(blueprint_with_queries, fn mutation, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootMutationType", mutation)
              end)

            blueprint_with_subscriptions =
              domain
              |> AshGraphql.Domain.subscriptions(
                all_domains,
                unquote(resources),
                action_middleware,
                unquote(schema),
                unquote(relay_ids?)
              )
              |> Enum.reduce(blueprint_with_mutations, fn subscription, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootSubscriptionType", subscription)
              end)

            managed_relationship_requirements =
              Process.get(:managed_relationship_requirements, [])

            Process.put(:managed_relationship_requirements, [])

            managed_relationship_types =
              AshGraphql.Resource.managed_relationship_definitions(
                managed_relationship_requirements,
                unquote(schema)
              )
              |> Enum.uniq_by(& &1.identifier)
              |> Enum.reject(fn type ->
                existing_types =
                  case blueprint_with_subscriptions do
                    %{schema_definitions: [%{type_definitions: type_definitions}]} ->
                      type_definitions

                    _ ->
                      []
                  end

                Enum.any?(existing_types, fn existing_type ->
                  existing_type.identifier == type.identifier
                end)
              end)

            domains = unquote(Enum.map(domains, &elem(&1, 0)))

            type_definitions =
              if unquote(first?) do
                embedded_types =
                  AshGraphql.get_embedded_types(
                    unquote(ash_resources),
                    domains,
                    unquote(schema),
                    unquote(relay_ids?),
                    labels
                  )

                global_maps =
                  AshGraphql.global_maps(
                    unquote(ash_resources),
                    domains,
                    unquote(schema),
                    __ENV__,
                    labels
                  )

                global_enums =
                  AshGraphql.global_enums(
                    unquote(ash_resources),
                    domains,
                    unquote(schema),
                    __ENV__,
                    labels
                  )

                global_unions =
                  AshGraphql.global_unions(
                    unquote(ash_resources),
                    domains,
                    unquote(schema),
                    __ENV__,
                    labels
                  )

                Enum.uniq_by(
                  AshGraphql.Domain.global_type_definitions(unquote(schema), __ENV__) ++
                    AshGraphql.Domain.type_definitions(
                      domain,
                      domains,
                      unquote(resources),
                      unquote(schema),
                      __ENV__,
                      true,
                      unquote(define_relay_types?),
                      unquote(relay_ids?),
                      action_middleware,
                      labels
                    ) ++
                    global_maps ++
                    global_enums ++
                    global_unions ++
                    embedded_types,
                  & &1.identifier
                )
              else
                AshGraphql.Domain.type_definitions(
                  domain,
                  domains,
                  unquote(resources),
                  unquote(schema),
                  __ENV__,
                  false,
                  false,
                  unquote(relay_ids?),
                  action_middleware,
                  labels
                )
              end

            new_defs =
              List.update_at(blueprint_with_subscriptions.schema_definitions, 0, fn schema_def ->
                # Deduplicate only structurally identical types — if two types
                # share an identifier but differ in structure, let Absinthe's
                # TypeNamesAreUnique phase report the conflict.
                new_types =
                  (type_definitions ++ managed_relationship_types)
                  |> Enum.reject(fn type ->
                    Enum.any?(schema_def.type_definitions, fn existing ->
                      existing == type
                    end)
                  end)

                %{
                  schema_def
                  | type_definitions: schema_def.type_definitions ++ new_types
                }
              end)

            blueprint = %{blueprint_with_subscriptions | schema_definitions: new_defs}

            if unquote(last?) do
              AshGraphql.warn_on_missing_absinthe_types(blueprint, labels)
            end

            {:ok, blueprint}
          end
        end

        if first? do
          Code.eval_quoted(auto_import_types, [], __ENV__)
        end

        @pipeline_modifier Module.concat([__MODULE__, domain, AshTypes])
      end
    end
  end

  @doc false
  def global_maps(resources, all_domains, schema, env, labels \\ nil) do
    resources
    |> Enum.flat_map(&AshGraphql.Resource.map_definitions(&1, all_domains, schema, env, labels))
    |> Enum.uniq_by(& &1.identifier)
  end

  @doc false
  def global_enums(resources, all_domains, schema, env, labels \\ nil) do
    resources
    |> Enum.flat_map(&all_attributes_and_arguments(&1, all_domains, [], false, labels))
    |> only_enum_types()
    |> Enum.uniq()
    |> Enum.map(fn type ->
      {name, identifier} =
        case type do
          Ash.Type.DurationName ->
            {"DurationName", :duration_name}

          type ->
            graphql_type = type.graphql_type([])
            {graphql_type |> to_string() |> Macro.camelize(), graphql_type}
        end

      %Absinthe.Blueprint.Schema.EnumTypeDefinition{
        module: schema,
        name: name,
        description: AshGraphql.Type.description(type, []),
        values:
          Enum.map(type.values() |> Enum.sort(), fn value ->
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

  @doc false
  def global_unions(resources, all_domains, schema, env, labels \\ nil) do
    resources
    |> Enum.flat_map(fn resource ->
      resource
      |> AshGraphql.Resource.global_unions(all_domains, labels)
      |> Enum.flat_map(fn {type, attribute} ->
        type_name = type.graphql_type(attribute.constraints)

        input_type_name =
          if function_exported?(type, :graphql_input_type, 1) do
            type.graphql_input_type(attribute.constraints)
          else
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
        all_domains,
        already_checked \\ [],
        return_new_checked? \\ false,
        labels \\ nil
      ) do
    if resource in already_checked do
      if return_new_checked? do
        {[], already_checked}
      else
        []
      end
    else
      already_checked = [resource | already_checked]

      attrs =
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.concat(all_arguments(resource, all_domains, labels))
        |> Enum.concat(Ash.Resource.Info.calculations(resource))
        |> Enum.concat(
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.filter(fn action ->
            action.type == :action && action.returns &&
              used_in_gql?(resource, action, all_domains, labels)
          end)
          |> Enum.map(fn action ->
            %{
              type: action.returns,
              constraints: action.constraints,
              name: action.name,
              description: nil,
              from_generic_action?: true
            }
          end)
        )
        |> Enum.concat(all_metadata(resource, all_domains, labels))

      {attrs, already_checked} =
        Enum.reduce(attrs, {[], already_checked}, fn
          %{type: type} = attr, {attrs, already_checked} ->
            constraints = Map.get(attr, :constraints, [])

            {nested, already_checked} =
              nested_attrs(type, all_domains, constraints, already_checked, labels)

            nested =
              Enum.map(nested, &Map.put(&1, :original_name, attr.name))

            {[attr | nested] ++ attrs, already_checked}
        end)

      {attrs, already_checked} =
        Enum.reduce(attrs, {[], already_checked}, fn attr, {attrs, already_checked} ->
          if attr.type in already_checked do
            {[attr | attrs], already_checked}
          else
            {new_attrs, already_checked} =
              expand_named_nested_attrs(
                Map.put(attr, :original_name, attr.name),
                already_checked
              )

            {[attr | new_attrs ++ attrs], already_checked}
          end
        end)

      attrs =
        Enum.filter(attrs, fn attr ->
          if Map.get(attr, :from_generic_action?) || Map.get(attr, :from_metadata?) do
            true
          else
            AshGraphql.Resource.Info.show_field?(
              resource,
              Map.get(attr, :original_name, attr.name)
            )
          end
        end)

      if return_new_checked? do
        {attrs, already_checked}
      else
        attrs
      end
    end
  end

  defp expand_named_nested_attrs(%{type: {:array, type}} = attr, already_checked) do
    expand_named_nested_attrs(
      %{attr | type: type, constraints: attr.constraints[:items] || []},
      already_checked
    )
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp expand_named_nested_attrs(%{type: type} = attr, already_checked)
       when type in [Ash.Type.Map, Ash.Type.Struct, Ash.Type.Keyset] do
    Enum.reduce(
      attr.constraints[:fields] || [],
      {[], already_checked},
      fn {key, config}, {attrs, already_checked} ->
        case config[:type] do
          {:array, type} ->
            fake_attr = %{
              attr
              | name: :"#{attr.name}_#{key}",
                type: type,
                constraints: config[:constraints][:items] || []
            }

            {new, already_checked} =
              expand_named_nested_attrs(
                fake_attr,
                already_checked
              )

            {[fake_attr | attrs] ++ new, already_checked}

          type ->
            fake_attr = %{
              attr
              | name: :"#{attr.name}_#{key}",
                type: type,
                constraints: config[:constraints] || []
            }

            {new, already_checked} =
              expand_named_nested_attrs(
                fake_attr,
                already_checked
              )

            {[fake_attr | attrs] ++ new, already_checked}
        end
      end
    )
    |> then(fn {attrs, already_checked} ->
      {[attr | attrs], already_checked}
    end)
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp expand_named_nested_attrs(%{type: Ash.Type.Union} = attr, already_checked) do
    Enum.reduce(
      attr.constraints[:types] || [],
      {[], already_checked},
      fn {key, config}, {attrs, already_checked} ->
        case config[:type] do
          {:array, type} ->
            fake_attr = %{
              attr
              | name: :"#{attr.name}_#{key}",
                type: type,
                constraints: config[:constraints][:items] || []
            }

            {new, already_checked} =
              expand_named_nested_attrs(
                fake_attr,
                already_checked
              )

            {[fake_attr | attrs] ++ new, already_checked}

          type ->
            fake_attr = %{
              attr
              | name: :"#{attr.name}_#{key}",
                type: type,
                constraints: config[:constraints] || []
            }

            {new, already_checked} =
              expand_named_nested_attrs(
                fake_attr,
                already_checked
              )

            {[fake_attr | attrs] ++ new, already_checked}
        end
      end
    )
    |> then(fn {attrs, already_checked} ->
      {[attr | attrs], already_checked}
    end)
  end

  defp expand_named_nested_attrs(attr, already_checked) do
    if Ash.Type.NewType.new_type?(attr.type) and attr.type not in already_checked do
      constraints = Ash.Type.NewType.constraints(attr.type, attr.constraints)

      already_checked = [attr.type | already_checked]

      expand_named_nested_attrs(
        %{attr | type: Ash.Type.NewType.subtype_of(attr.type), constraints: constraints},
        already_checked
      )
    else
      {[], already_checked}
    end
  end

  @doc false
  def relay_queries(domains_with_resources, all_domains, schema, env, labels \\ nil) do
    type_to_domain_and_resource_map =
      domains_with_resources
      |> Enum.flat_map(fn {domain, resources} ->
        resources
        |> Enum.flat_map(fn resource ->
          type = AshGraphql.Resource.Info.type(resource)

          if type &&
               (is_nil(labels) ||
                  AshGraphql.Resource.primary_key_get_query(resource, all_domains, labels)) do
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
          {{AshGraphql.Graphql.Resolver, :resolve_node},
           {type_to_domain_and_resource_map, all_domains}}
        ],
        complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
        module: schema,
        description: "Retrieves a Node from its global id",
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :node},
        __reference__: AshGraphql.Resource.ref(__ENV__)
      }
    ]
  end

  defp nested_attrs({:array, type}, domain, constraints, already_checked, labels) do
    nested_attrs(type, domain, constraints[:items] || [], already_checked, labels)
  end

  defp nested_attrs(Ash.Type.Union, domain, constraints, already_checked, labels) do
    Enum.reduce(
      constraints[:types] || [],
      {[], already_checked},
      fn {_, config}, {attrs, already_checked} ->
        case config[:type] do
          {:array, type} ->
            {new, already_checked} =
              nested_attrs(
                type,
                domain,
                config[:constraints][:items] || [],
                already_checked,
                labels
              )

            {attrs ++ new, already_checked}

          type ->
            {new, already_checked} =
              nested_attrs(type, domain, config[:constraints] || [], already_checked, labels)

            {attrs ++ new, already_checked}
        end
      end
    )
  end

  defp nested_attrs(type, all_domains, constraints, already_checked, labels) do
    cond do
      AshGraphql.Resource.embedded?(type) ->
        type
        |> unwrap_type()
        |> all_attributes_and_arguments(all_domains, already_checked, true, labels)

      Ash.Type.NewType.new_type?(type) && type not in already_checked ->
        constraints = Ash.Type.NewType.constraints(type, constraints)
        subtype = Ash.Type.NewType.subtype_of(type)

        if subtype in [Ash.Type.Map, Ash.Type.Struct, Ash.Type.Keyword, Ash.Type.Tuple] &&
             !Enum.empty?(constraints[:fields] || []) &&
             function_exported?(type, :graphql_type, 1) do
          fake_attr = %{
            name: :nested_type,
            type: type,
            constraints: constraints,
            description: nil,
            allow_nil?: true
          }

          {[fake_attr], already_checked}
        else
          nested_attrs(subtype, all_domains, constraints, [type | already_checked], labels)
        end

      true ->
        {[], already_checked}
    end
  end

  @doc false
  def get_embed(type) do
    if Ash.Type.NewType.new_type?(type) do
      Ash.Type.NewType.subtype_of(type)
    else
      type
    end
  end

  @doc """
  Use this to load any requested fields for a result when it is returned
  from a custom resolver or mutation.

  ## Determining required fields

  If you have a custom query/mutation that returns the record at a "path" in
  the response, then specify the path. In the example below, `path` would be
  `["record"]`. This is how we know what fields to load.

  ```elixir
  query something() {
    result {
      record { # <- this is the instance
        id
        name
      }
    }
  }
  ```

  ## Options

  - `path`: The path to the record(s) in the response
  - `domain`: The domain to use when loading the fields. Determined from the resource by default.
  - `authorize?`: Whether to authorize access to fields. Defaults to the domain's setting (which defaults to `true`).
  - `actor`: The actor to use when authorizing access to fields. Defaults to the actor in the resolution context.
  - `tenant`: The tenant to use when authorizing access to fields. Defaults to the tenant in the resolution context.
  """
  @spec load_fields(input, Ash.Resource.t(), Absinthe.Resolution.t(), opts :: Keyword.t()) ::
          {:ok, input} | {:error, term()}
        when input: Ash.Resource.Record.t() | list(Ash.Resource.Record.t()) | Ash.Page.page()
  def load_fields(data, resource, resolution, opts \\ []) do
    Ash.load(data, load_fields_on_query(resource, resolution, opts), resource: resource)
  end

  @doc """
  The same as `load_fields/4`, but modifies the provided query to load the required fields.

  This allows doing the loading in a single query rather than two separate queries.
  """
  @spec load_fields_on_query(
          query :: Ash.Query.t() | Ash.Resource.t(),
          Absinthe.Resolution.t(),
          Keyword.t()
        ) ::
          Ash.Query.t()
  def load_fields_on_query(query, resolution, opts \\ []) do
    query =
      query
      |> Ash.Query.new()

    resource = query.resource

    domain =
      opts[:domain] || Ash.Resource.Info.domain(resource) ||
        raise ArgumentError,
              "Could not determine domain for #{inspect(resource)}. Please specify the `domain` option."

    tenant = Keyword.get(opts, :tenant, Map.get(resolution.context, :tenant))
    authorize? = Keyword.get(opts, :authorize?, AshGraphql.Domain.Info.authorize?(domain))
    actor = Keyword.get(opts, :actor, Map.get(resolution.context, :actor))

    query
    |> Ash.Query.set_tenant(tenant)
    |> Ash.Query.set_context(AshGraphql.ContextHelpers.get_context(resolution.context))
    |> AshGraphql.Graphql.Resolver.select_fields(
      resource,
      resolution,
      nil,
      opts[:path] || []
    )
    |> AshGraphql.Graphql.Resolver.load_fields(
      [
        domain: domain,
        tenant: tenant,
        authorize?: authorize?,
        actor: actor
      ],
      resource,
      resolution,
      resolution.path,
      resolution.context,
      nil
    )
  end

  @doc """
  Applies AshGraphql's error handling logic if the value is an `{:error, error}` tuple, otherwise returns the value

  Useful for automatically handling errors in custom queries

  ## Options

  - `domain`: The domain to use when loading the fields. Determined from the resource by default.
  """
  @spec handle_errors(
          result :: term,
          resource :: Ash.Resource.t(),
          resolution :: Absinthe.Resolution.t(),
          opts :: Keyword.t()
        ) ::
          term()
  def handle_errors(result, resource, resolution, opts \\ [])

  def handle_errors({:error, error}, resource, resolution, opts) do
    domain =
      Ash.Resource.Info.domain(resource) || opts[:domain] ||
        raise ArgumentError,
              "Could not determine domain for #{inspect(resource)}. Please specify the `domain` option."

    AshGraphql.Graphql.Resolver.to_resolution(
      {:error, List.wrap(error)},
      resolution.context,
      domain
    )
  end

  def handle_errors(result, _, _, _), do: result

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
    attributes
    |> Enum.filter(&AshGraphql.Resource.define_type?(&1.type, &1.constraints))
    |> Enum.flat_map(fn attribute ->
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
         function_exported?(type, :graphql_type, 1) do
      type
    end
  end

  # sobelow_skip ["DOS.BinToAtom"]
  @doc false
  def get_embedded_types(all_resources, all_domains, schema, relay_ids?, labels \\ nil) do
    all_resources
    |> Enum.flat_map(fn resource ->
      resource
      |> all_attributes_and_arguments(all_domains, [], false, labels)
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
          type when type in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Struct] ->
            if fields = attribute.constraints[:fields] do
              Enum.flat_map(fields, fn {name, config} ->
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
            else
              []
            end

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
        Enum.filter(
          [
            AshGraphql.Resource.type_definition(
              embedded_type,
              Ash.EmbeddableType.ShadowDomain,
              [Ash.EmbeddableType.ShadowDomain],
              schema,
              relay_ids?
            ),
            AshGraphql.Resource.embedded_type_input(
              source_resource,
              attribute,
              embedded_type,
              schema
            )
          ],
          & &1
        ) ++
          AshGraphql.Resource.enum_definitions(embedded_type, schema, __ENV__)
      else
        []
      end
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  defp all_arguments(resource, all_domains, labels) do
    action_arguments =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.filter(&used_in_gql?(resource, &1, all_domains, labels))
      |> Enum.flat_map(& &1.arguments)

    calculation_arguments =
      resource
      |> Ash.Resource.Info.public_calculations()
      |> Enum.flat_map(& &1.arguments)

    action_arguments ++ calculation_arguments
  end

  defp all_metadata(resource, all_domains, labels) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.filter(&used_in_gql?(resource, &1, all_domains, labels))
    |> Enum.flat_map(&Map.get(&1, :metadata, []))
    |> Enum.map(fn metadata ->
      %{
        type: metadata.type,
        constraints: metadata.constraints,
        name: metadata.name,
        description: metadata.description,
        from_metadata?: true
      }
    end)
  end

  defp used_in_gql?(resource, %{name: name}, all_domains, labels) do
    if Ash.Resource.Info.embedded?(resource) do
      # We should actually check if any resource refers to this action for this
      true
    else
      mutations = AshGraphql.Resource.Info.mutations(resource, all_domains, labels)
      queries = AshGraphql.Resource.Info.queries(resource, all_domains, labels)

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

  @doc """
  Validates the `response_metadata` configuration at compile time.

  Accepts:
  - `nil` or `false` to disable
  - An atom key to enable with default handler (e.g., `:metadata`)
  - `{key, {module, function, args}}` tuple for a custom handler

  Raises `ArgumentError` for invalid values.
  """
  def validate_response_metadata!(nil), do: :ok
  def validate_response_metadata!(false), do: :ok

  def validate_response_metadata!(true) do
    raise ArgumentError, """
    Invalid `response_metadata` configuration: true

    You must specify the key under which metadata will appear in extensions.

    Example:
      use AshGraphql,
        domains: [...],
        response_metadata: :my_extension_key
    """
  end

  def validate_response_metadata!(key) when is_atom(key) do
    :ok
  end

  def validate_response_metadata!({key, {module, function, args}})
      when is_atom(key) and is_atom(module) and is_atom(function) and is_list(args) do
    :ok
  end

  def validate_response_metadata!(invalid) do
    raise ArgumentError, """
    Invalid `response_metadata` configuration: #{inspect(invalid)}

    Expected one of:
      - An atom key to enable with default handler
      - `false` or `nil` to disable response metadata
      - `{key, {Module, :function, args}}` tuple for a custom handler

    Example:
      use AshGraphql,
        domains: [...],
        response_metadata: :my_extension_key

    Or with a custom handler:
      use AshGraphql,
        domains: [...],
        response_metadata: {:my_extension_key, {MyApp.MetadataHandler, :build, []}}
    """
  end

  @doc false
  def validate_default_types!(nil, _option), do: :ok
  def validate_default_types!([], _option), do: :ok

  def validate_default_types!(types, option) when is_list(types) do
    unless Keyword.keyword?(types) do
      raise ArgumentError, """
      Invalid `#{option}` configuration: #{inspect(types)}

      Expected a keyword list of {Ash.Type module, graphql_type} pairs.

      Example:
        use AshGraphql,
          domains: [...],
          #{option}: [{MyApp.OpaqueId, :string}]
      """
    end

    Enum.each(types, fn
      {type, _graphql_type} when is_atom(type) ->
        :ok

      other ->
        raise ArgumentError, """
        Invalid `#{option}` entry: #{inspect(other)}

        Expected {Ash.Type module, graphql_type}.

        Example:
          use AshGraphql,
            domains: [...],
            #{option}: [{MyApp.OpaqueId, :string}]
        """
    end)

    :ok
  end

  def validate_default_types!(invalid, option) do
    raise ArgumentError, """
    Invalid `#{option}` configuration: #{inspect(invalid)}

    Expected a keyword list of {Ash.Type module, graphql_type} pairs.

    Example:
      use AshGraphql,
        domains: [...],
        #{option}: [{MyApp.OpaqueId, :string}]
    """
  end

  @doc false
  def validate_labels!(nil, _resources, _all_domains), do: :ok

  def validate_labels!([], _resources, _all_domains) do
    raise ArgumentError, """
    Invalid `labels` configuration: []

    When `labels` is provided, at least one label must be specified.
    """
  end

  def validate_labels!(labels, resources, all_domains) do
    labels = List.wrap(labels)

    available_labels =
      resources
      |> Enum.filter(&(AshGraphql.Resource in Spark.extensions(&1)))
      |> Enum.flat_map(fn resource ->
        AshGraphql.Resource.Info.queries(resource, all_domains) ++
          AshGraphql.Resource.Info.mutations(resource, all_domains)
      end)
      |> Enum.flat_map(&List.wrap(Map.get(&1, :labels, [])))
      |> Enum.uniq()

    missing_labels = labels -- available_labels

    if missing_labels != [] do
      raise ArgumentError, """
      Invalid `labels` configuration: #{inspect(labels)}

      The following labels are not used by any GraphQL query or mutation in the selected domains:

      #{Enum.map_join(missing_labels, "\n", &"  * #{inspect(&1)}")}
      """
    end

    :ok
  end

  @doc false
  def warn_on_missing_absinthe_types(_blueprint, nil), do: :ok

  def warn_on_missing_absinthe_types(blueprint, labels) do
    missing_types =
      blueprint
      |> missing_absinthe_types()
      |> Enum.sort()

    if missing_types != [] do
      IO.warn("""
      AshGraphql schema labels #{inspect(List.wrap(labels))} include operations that reference GraphQL types not defined or imported in the Absinthe schema:

      #{Enum.map_join(missing_types, "\n", &"  * #{inspect(&1)}")}

      AshGraphql can generate transitive AshGraphql-managed types for labelled operations, but it cannot infer where manually defined Absinthe types are declared. Define them in the schema or import them with `import_types/1`.
      """)
    end

    :ok
  end

  @builtin_absinthe_type_identifiers MapSet.new([
                                       :id,
                                       :string,
                                       :integer,
                                       :float,
                                       :boolean
                                     ])

  defp missing_absinthe_types(blueprint) do
    type_definitions =
      blueprint
      |> Map.get(:schema_definitions, [])
      |> Enum.flat_map(&Map.get(&1, :type_definitions, []))

    defined_types =
      type_definitions
      |> Enum.flat_map(&[Map.get(&1, :identifier), Map.get(&1, :name)])
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()
      |> MapSet.union(@builtin_absinthe_type_identifiers)

    referenced_types =
      type_definitions
      |> Enum.flat_map(&type_references/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    referenced_types
    |> MapSet.difference(defined_types)
    |> MapSet.to_list()
  end

  defp type_references(%Absinthe.Blueprint.TypeReference.Name{name: name}), do: [name]

  defp type_references(%_struct{} = value) do
    value
    |> Map.from_struct()
    |> Map.take([:arguments, :fields, :interfaces, :of_type, :type, :types])
    |> Enum.flat_map(fn {_key, value} -> type_references(value) end)
  end

  defp type_references(value) when is_list(value) do
    Enum.flat_map(value, &type_references/1)
  end

  defp type_references(value) when is_atom(value), do: [value]

  defp type_references(_), do: []

  @doc false
  def validate_domains_for_relationships!(ash_resources, all_domains) do
    for resource <- ash_resources,
        AshGraphql.Resource in Spark.extensions(resource),
        relationship <- Ash.Resource.Info.public_relationships(resource),
        AshGraphql.Resource in Spark.extensions(relationship.destination),
        relationship.destination not in ash_resources do
      destination_domain = Ash.Resource.Info.domain(relationship.destination)

      domain_hint =
        if destination_domain do
          "Add #{inspect(destination_domain)} to your schema's domain list:\n\n" <>
            "    use AshGraphql, domains: #{inspect(all_domains ++ [destination_domain])}"
        else
          "Make sure the domain for #{inspect(relationship.destination)} is included in your schema's domain list."
        end

      raise """
      #{inspect(resource)} has a relationship `#{relationship.name}` to #{inspect(relationship.destination)}, \
      but #{inspect(relationship.destination)}'s domain is not included in this schema.

      #{domain_hint}
      """
    end

    :ok
  end
end
