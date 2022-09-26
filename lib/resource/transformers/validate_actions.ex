defmodule AshGraphql.Resource.Transformers.ValidateActions do
  @moduledoc "Ensures that all referenced actiosn exist"
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def after_compile?, do: true

  def transform(dsl) do
    dsl
    |> Transformer.get_entities([:graphql, :queries])
    |> Enum.concat(Transformer.get_entities(dsl, [:graphql, :mutations]))
    |> Enum.each(fn query_or_mutation ->
      type =
        case query_or_mutation do
          %AshGraphql.Resource.Query{} ->
            :read

          %AshGraphql.Resource.Mutation{type: type} ->
            type
        end

      available_actions = Transformer.get_entities(dsl, [:actions]) || []

      action =
        Enum.find(available_actions, fn action ->
          action.name == query_or_mutation.action
        end)

      unless action do
        resource = Transformer.get_persisted(dsl, :module)

        raise Spark.Error.DslError,
          module: resource,
          message: """
          No such action #{query_or_mutation.action} of type #{type} on #{inspect(resource)}

          Available #{type} actions:

          #{available_actions}
          """
      end
    end)

    {:ok, dsl}
  end
end
