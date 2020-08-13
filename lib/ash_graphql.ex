defmodule AshGraphql do
  @moduledoc """
  Documentation for `AshGraphql`.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [api: opts[:api]] do
      defmodule AshTypes do
        alias Absinthe.{Phase, Pipeline, Blueprint}

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

          new_defs =
            List.update_at(blueprint_with_mutations.schema_definitions, 0, fn schema_def ->
              %{
                schema_def
                | type_definitions:
                    schema_def.type_definitions ++
                      AshGraphql.Api.type_definitions(api, __MODULE__)
              }
            end)

          {:ok, %{blueprint_with_mutations | schema_definitions: new_defs}}
        end
      end

      @pipeline_modifier AshTypes
    end
  end
end
