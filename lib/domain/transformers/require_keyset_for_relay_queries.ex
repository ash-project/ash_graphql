# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Domain.Transformers.RequireKeysetForRelayQueries do
  # Ensures that all relay queries configure keyset pagination
  @moduledoc false

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def after_compile?, do: true

  def transform(dsl) do
    dsl
    |> AshGraphql.Domain.Info.queries()
    |> Enum.each(fn query ->
      if Map.get(query, :relay?) do
        action = Ash.Resource.Info.action(query.resource, query.action)

        unless action.pagination && action.pagination.keyset? do
          raise Spark.Error.DslError,
            module: Transformer.get_persisted(dsl, :module),
            message: "Relay queries must support keyset pagination",
            path: [:graphql, :queries, query.name]
        end
      end
    end)

    {:ok, dsl}
  end
end
