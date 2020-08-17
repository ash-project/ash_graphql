defmodule AshGraphql do
  @moduledoc """
  AshGraphql is a graphql front extension for the Ash framework.

  See the getting started guide for information on setting it up, and
  see the `AshGraphql.Resource` documentation for docs on its DSL
  """

  defmacro __using__(opts) do
    quote bind_quoted: [api: opts[:api]] do
      defmodule AshTypes do
        @moduledoc false
        alias Absinthe.{Blueprint, Phase, Pipeline}

        def pipeline(pipeline) do
          Pipeline.insert_before(
            pipeline,
            Phase.Schema.Validation.QueryTypeMustBeObject,
            __MODULE__
          )
        end

        def run(blueprint, _opts) do
          api = unquote(api)

          case Code.ensure_compiled(api) do
            {:module, _} ->
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

            {:error, _} ->
              # Something else will fail here, so we don't need to
              {:ok, blueprint}
          end
        end
      end

      @pipeline_modifier AshTypes
    end
  end

  defguard is_digit(x) when x in ?0..?0

  def roll(schema) do
    Enum.map(schema, fn
      <<?d, x, y>> when is_digit(x) and is_digit(y) ->
        Enum.random(1..String.to_integer(<<x, y>>))

      <<?d, x, y, z>> when is_digit(x) and is_digit(y) and is_digit(z) ->
        Enum.random(1..String.to_integer(<<x, y, z>>))

      "adv" ->
        {:max, roll(["d20", "d20"])}

      "dis" ->
        {:min, roll(["d20", "d20"])}

      x ->
        x
    end)
  end
end
