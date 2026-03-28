# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.FlattenQueryMutationGroupsTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource
  alias Spark.Dsl.Extension

  test "flattening assigns the same group to list queries and query actions under group" do
    entities = Extension.get_entities(AshGraphql.Test.GroupedQueriesResource, [:graphql, :queries])

    assert length(entities) == 2

    assert Enum.all?(entities, &(&1.group == :content))

    assert Enum.any?(entities, &match?(%Resource.Query{}, &1))
    assert Enum.any?(entities, &match?(%Resource.Action{}, &1))
  end

  test "duplicate graphql query names inside one group fail compilation" do
    assert_raise Spark.Error.DslError, ~r/Duplicate GraphQL query field.*same_name/s, fn ->
      defmodule DuplicateGroupedQueryResource do
        use Ash.Resource,
          domain: AshGraphql.Test.Domain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshGraphql.Resource]

        graphql do
          type(:duplicate_grouped_query)

          queries do
            group :dup do
              list(:same_name, :read)
              list(:same_name, :read)
            end
          end
        end

        actions do
          default_accept(:*)
          defaults([:read])
        end

        attributes do
          uuid_primary_key(:id)
        end
      end
    end
  end
end
