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
              Phase.Schema.Validation.QueryTypeMustBeObject,
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
                AshGraphql.Api.global_type_definitions(__MODULE__) ++
                  AshGraphql.Api.type_definitions(api, __MODULE__)
              else
                AshGraphql.Api.type_definitions(api, __MODULE__)
              end

            new_defs =
              List.update_at(blueprint_with_mutations.schema_definitions, 0, fn schema_def ->
                %{
                  schema_def
                  | imports: [{Absinthe.Type.Custom, []} | List.wrap(schema_def.imports)],
                    type_definitions: schema_def.type_definitions ++ type_definitions
                }
              end)

            {:ok, %{blueprint_with_mutations | schema_definitions: new_defs}}
          end
        end

        @pipeline_modifier Module.concat(api, AshTypes)
      end
    end
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
