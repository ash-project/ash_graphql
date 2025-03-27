defmodule AshGraphql.Resource.Transformers.ValidateActions do
  # Ensures that all referenced actiosn exist
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def after_compile?, do: true

  def transform(dsl) do
    dsl
    |> Transformer.get_entities([:graphql, :queries])
    |> Enum.concat(Transformer.get_entities(dsl, [:graphql, :mutations]))
    |> Enum.each(fn query_or_mutation ->
      types =
        case query_or_mutation do
          %AshGraphql.Resource.Query{} ->
            [:read]

          %AshGraphql.Resource.Action{} ->
            []

          %AshGraphql.Resource.Mutation{type: :validate} ->
            [:create, :update]

          %AshGraphql.Resource.Mutation{type: type} ->
            [type]
        end

      available_actions = Transformer.get_entities(dsl, [:actions]) || []

      available_actions =
        if Enum.empty?(types) do
          available_actions
        else
          Enum.filter(available_actions, fn action ->
            action.type in types
          end)
        end

      action =
        Enum.find(available_actions, fn action ->
          action.name == query_or_mutation.action
        end)

      unless action do
        resource = Transformer.get_persisted(dsl, :module)

        raise Spark.Error.DslError,
          module: resource,
          message: """
          No such action #{query_or_mutation.action} of types #{inspect(types)} on #{inspect(resource)}

          Available #{inspect(types)} actions:

          #{Enum.map_join(available_actions, ", ", & &1.name)}
          """
      end
    end)

    {:ok, dsl}
  end
end
