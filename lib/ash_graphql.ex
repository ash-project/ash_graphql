defmodule AshGraphql do
  @moduledoc """
  AshGraphql is a graphql front extension for the Ash framework.

  See the [getting started guide](/getting_started.md) for information on setting it up, and
  see the `AshGraphql.Resource` documentation for docs on its DSL
  """

  defmacro __using__(opts) do
    quote bind_quoted: [apis: opts[:apis], api: opts[:api]] do
      apis =
        api
        |> List.wrap()
        |> Kernel.++(List.wrap(apis))

      apis =
        apis
        |> Enum.map(&{&1, false})
        |> List.update_at(0, fn {api, _} -> {api, true} end)

      for {api, first?} <- apis do
        defmodule Module.concat(api, AshTypes) do
          @moduledoc false
          alias Absinthe.{Blueprint, Phase, Pipeline}

          Code.ensure_compiled(api)

          def pipeline(pipeline) do
            Pipeline.insert_before(
              pipeline,
              Absinthe.Phase.Schema.ApplyDeclaration,
              __MODULE__
            )
          end

          def run(blueprint, _opts) do
            api = unquote(api)

            Code.ensure_compiled(api)

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
                embedded_types = AshGraphql.get_embedded_types(unquote(apis))

                AshGraphql.Api.global_type_definitions(__MODULE__) ++
                  AshGraphql.Api.type_definitions(api, __MODULE__) ++
                  embedded_types
              else
                AshGraphql.Api.type_definitions(api, __MODULE__)
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
        end

        @pipeline_modifier Module.concat(api, AshTypes)
      end
    end
  end

  def get_embedded_types(apis) do
    apis
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Ash.Api.resources/1)
    |> Enum.flat_map(fn resource ->
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.map(&{resource, &1})
    end)
    |> Enum.filter(fn {_resource, attribute} ->
      Ash.Type.embedded_type?(attribute.type)
    end)
    |> Enum.map(fn
      {source_resource, attribute} ->
        {source_resource, attribute, embedded_resource(attribute.type)}
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded} ->
      [{source_resource, attribute, embedded}] ++ get_nested_embedded_types(embedded)
    end)
    |> Enum.flat_map(fn {source_resource, attribute, embedded_type} ->
      if AshGraphql.Resource.type(embedded_type) do
        [
          AshGraphql.Resource.type_definition(
            embedded_type,
            Module.concat(embedded_type, ShadowApi),
            __MODULE__
          ),
          AshGraphql.Resource.embedded_type_input(
            source_resource,
            attribute,
            embedded_type,
            __MODULE__
          )
        ]
      else
        [
          AshGraphql.Resource.embedded_type_input(
            source_resource,
            attribute,
            embedded_type,
            __MODULE__
          )
        ]
      end
    end)
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

  def add_context(ctx, apis) do
    dataloader =
      apis
      |> List.wrap()
      |> Enum.reduce(Dataloader.new(), fn api, dataloader ->
        Dataloader.add_source(
          dataloader,
          api,
          AshGraphql.Dataloader.new(api)
        )
      end)

    Map.put(ctx, :loader, dataloader)
  end
end
