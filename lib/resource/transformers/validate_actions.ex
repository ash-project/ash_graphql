defmodule AshGraphql.Resource.Transformers.ValidateActions do
  @moduledoc "Ensures that all referenced actiosn exist"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  def transform(resource, dsl) do
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

      unless Ash.Resource.Info.action(
               resource,
               query_or_mutation.action
             ) do
        available_actions =
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.filter(&(&1.type == type))
          |> Enum.map(&"  * #{&1.name}\n")

        raise Ash.Error.Dsl.DslError,
          module: __MODULE__,
          message: """
          No such action #{query_or_mutation.action} of type #{type} on #{inspect(resource)}

          Available #{type} actions:

          #{available_actions}
          """
      end
    end)

    {:ok, dsl}
  end

  def after?(Ash.Resource.Transformers.ValidatePrimaryActions), do: true
  def after?(_), do: false
end
