# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Domain.Transformers.ValidateActions do
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
      type =
        case query_or_mutation do
          %AshGraphql.Resource.Query{} ->
            :read

          %AshGraphql.Resource.Action{} ->
            nil

          %AshGraphql.Resource.Mutation{type: type} ->
            type
        end

      available_actions = Ash.Resource.Info.actions(query_or_mutation.resource)

      available_actions =
        if type do
          Enum.filter(available_actions, fn action ->
            action.type == type
          end)
        else
          available_actions
        end

      action =
        Enum.find(available_actions, fn action ->
          action.name == query_or_mutation.action
        end)

      unless action do
        raise Spark.Error.DslError,
          module: Transformer.get_persisted(dsl, :module),
          message: """
          No such action #{query_or_mutation.action} of type #{type} on #{inspect(query_or_mutation.resource)}

          Available #{type} actions:

          #{Enum.map_join(available_actions, ", ", & &1.name)}
          """
      end
    end)

    {:ok, dsl}
  end
end
