defmodule AshGraphql do
  @moduledoc """
  AshGraphql is a GraphQL extension for the Ash framework.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [apis: opts[:apis], api: opts[:api]], generated: true do
      apis =
        api
        |> List.wrap()
        |> Kernel.++(List.wrap(apis))

      apis =
        apis
        |> Enum.map(fn
          {api, registry} ->
            {api, registry}

          api ->
            raise """
            Must now include registry with api when using `AshGraphql`. For example:

              use AshGraphql, apis: [{My.App.Api, My.App.Registry}]

            In order to ensure the absinthe schema is recompiled properly, the Registry for each Api must be provided explicitly.
            """
        end)
        |> Enum.map(fn {api, registry} -> {api, registry, false} end)
        |> List.update_at(0, fn {api, registry, _} -> {api, registry, true} end)

      schema = __MODULE__

      for {api, registry, first?} <- apis do
        defmodule Module.concat(api, AshTypes) do
          @moduledoc false
          alias Absinthe.{Blueprint, Phase, Pipeline}

          # Ensures the api is compiled, and any errors are raised
          _ = api.spark_dsl_config()
          _ = registry.spark_dsl_config()

          def pipeline(pipeline) do
            Pipeline.insert_before(
              pipeline,
              Absinthe.Phase.Schema.ApplyDeclaration,
              __MODULE__
            )
          end

          @dialyzer {:nowarn_function, {:run, 2}}
          def run(blueprint, _opts) do
            api = unquote(api)

            Code.ensure_compiled!(api)
            blueprint = AshGraphql.add_root_types(blueprint, __ENV__)

            blueprint_with_queries =
              api
              |> AshGraphql.Api.queries(__MODULE__)
              |> Enum.reduce(blueprint, fn query, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootQueryType", query)
              end)

            blueprint_with_mutations =
              api
              |> AshGraphql.Api.mutations(__MODULE__)
              |> Enum.reduce(blueprint_with_queries, fn mutation, blueprint ->
                Absinthe.Blueprint.add_field(blueprint, "RootMutationType", mutation)
              end)

            type_definitions =
              if unquote(first?) do
                apis = unquote(Enum.map(apis, &elem(&1, 0)))
                embedded_types = AshGraphql.get_embedded_types(apis, unquote(schema))

                global_enums = AshGraphql.global_enums(apis, unquote(schema), __ENV__)

                AshGraphql.Api.global_type_definitions(unquote(schema), __ENV__) ++
                  AshGraphql.Api.type_definitions(api, unquote(schema), __ENV__, true) ++
                  global_enums ++
                  embedded_types
              else
                AshGraphql.Api.type_definitions(api, unquote(schema), __ENV__, false)
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

        @pipeline_modifier Module.concat(api, AshTypes)
      end
    end
  end

  def global_enums(apis, schema, env) do
    apis
    |> Enum.flat_map(&Ash.Api.Info.resources/1)
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
            %Absinthe.Blueprint.Schema.EnumValueDefinition{
              module: schema,
              identifier: value,
              __reference__: AshGraphql.Resource.ref(env),
              name: String.upcase(to_string(value)),
              value: value
            }
          end),
        identifier: identifier,
        __reference__: AshGraphql.Resource.ref(env)
      }
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  defp all_attributes_and_arguments(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(all_arguments(resource))
    |> Enum.concat(Ash.Resource.Info.calculations(resource))
    |> Enum.flat_map(fn %{type: type} = attr ->
      if Ash.Type.embedded_type?(type) do
        [
          attr
          | type
            |> embedded_resource()
            |> all_attributes_and_arguments()
        ]
      else
        [attr]
      end
    end)
  end

  # defp embedded_enums(%{type: type}) do
  #   if Ash.Type.embedded_type?(type) do
  #     type
  #   end

  # end

  defp only_enum_types(attributes) do
    Enum.flat_map(attributes, fn attribute ->
      case enum_type(attribute.type) do
        nil ->
          []

        type ->
          [type]
      end
    end)
  end

  def get_embedded_types(apis, schema) do
    apis
    |> Enum.flat_map(&Ash.Api.Info.resources/1)
    |> Enum.flat_map(fn resource ->
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.concat(all_arguments(resource))
      |> Enum.concat(Ash.Resource.Info.calculations(resource))
      |> Enum.map(&{resource, &1})
    end)
    |> Enum.filter(fn {_resource, attribute} ->
      attribute.type
      |> embedded_resource()
      |> Ash.Type.embedded_type?()
    end)
    |> Enum.map(fn
      {source_resource, attribute} ->
        {source_resource, attribute, embedded_resource(attribute.type)}
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded} ->
      [{source_resource, attribute, embedded}] ++ get_nested_embedded_types(embedded)
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded_type} ->
      if AshGraphql.Resource.Info.type(embedded_type) do
        [
          AshGraphql.Resource.type_definition(
            embedded_type,
            Module.concat(embedded_type, ShadowApi),
            schema
          ),
          AshGraphql.Resource.embedded_type_input(
            source_resource,
            attribute,
            embedded_type,
            schema
          )
        ] ++
          AshGraphql.Resource.enum_definitions(embedded_type, schema, __ENV__)
      else
        [
          AshGraphql.Resource.embedded_type_input(
            source_resource,
            attribute,
            embedded_type,
            schema
          )
        ] ++ AshGraphql.Resource.enum_definitions(embedded_type, schema, __ENV__)
      end
    end)
    |> Enum.uniq_by(& &1.identifier)
  end

  def add_root_types(%Absinthe.Blueprint{} = blueprint, env) do
    %{
      blueprint
      | schema_definitions: Enum.map(blueprint.schema_definitions, &do_add_root_types(&1, env))
    }
  end

  defp do_add_root_types(%Absinthe.Blueprint.Schema.SchemaDefinition{} = schema, env) do
    schema
    |> add_root_query_type(env)
    |> add_root_mutation_type(env)
  end

  defp add_root_query_type(schema, env) do
    if Enum.any?(schema.type_definitions, &(&1.name == "RootQueryType")) do
      schema
    else
      root_query = %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        name: "RootQueryType",
        identifier: :query,
        module: AshHqWeb.Schema,
        description: nil,
        interfaces: [],
        interface_blueprints: [],
        fields: [],
        directives: [],
        is_type_of: {:ref, env.module, {Absinthe.Blueprint.Schema.ObjectTypeDefinition, :query}},
        source_location: nil,
        flags: %{},
        imports: [],
        errors: [],
        __reference__: AshGraphql.Resource.ref(env),
        __private__: []
      }

      %{schema | type_definitions: [root_query | schema.type_definitions]}
    end
  end

  defp add_root_mutation_type(schema, env) do
    if Enum.any?(schema.type_definitions, &(&1.name == "RootMutationType")) do
      schema
    else
      root_mutation = %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        name: "RootMutationType",
        identifier: :mutation,
        module: AshHqWeb.Schema,
        description: nil,
        interfaces: [],
        interface_blueprints: [],
        fields: [],
        directives: [],
        is_type_of:
          {:ref, env.module, {Absinthe.Blueprint.Schema.ObjectTypeDefinition, :mutation}},
        source_location: nil,
        flags: %{},
        imports: [],
        errors: [],
        __reference__: AshGraphql.Resource.ref(env),
        __private__: []
      }

      %{schema | type_definitions: [root_mutation | schema.type_definitions]}
    end
  end

  defp all_arguments(resource) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.flat_map(& &1.arguments)
  end

  defp enum_type({:array, type}), do: enum_type(type)

  defp enum_type(type) do
    if is_atom(type) && :erlang.function_exported(type, :values, 0) &&
         :erlang.function_exported(type, :graphql_type, 0) do
      type
    end
  end

  defp embedded_resource({:array, type}), do: embedded_resource(type)
  defp embedded_resource(type), do: type

  defp get_nested_embedded_types(embedded_type) do
    embedded_type
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&Ash.Type.embedded_type?(&1.type))
    |> Enum.map(fn attribute ->
      {attribute, embedded_resource(attribute.type)}
    end)
    |> Enum.flat_map(fn {attribute, embedded} ->
      [{embedded_type, attribute, embedded}] ++ get_nested_embedded_types(embedded)
    end)
  end

  def add_context(ctx, apis, options \\ []) do
    options = Keyword.put(options, :get_policy, :tuples)
    empty_dataloader = Dataloader.new(options)

    dataloader =
      apis
      |> List.wrap()
      |> Enum.reduce(empty_dataloader, fn {api, _registry}, dataloader ->
        Dataloader.add_source(
          dataloader,
          api,
          AshGraphql.Dataloader.new(api)
        )
      end)

    Map.put(ctx, :loader, dataloader)
  end
end
