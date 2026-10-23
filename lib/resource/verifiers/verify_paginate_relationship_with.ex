# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyPaginateRelationshipWith do
  # Validates the paginate_relationship_with option
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @valid_strategies [
    nil,
    :none,
    :keyset,
    :offset,
    :relay
  ]

  def verify(dsl) do
    many_relationships =
      dsl
      |> Verifier.get_entities([:relationships])
      |> Enum.filter(&(&1.cardinality == :many))

    many_relationship_names = Enum.map(many_relationships, & &1.name)

    manual_relationship_names =
      many_relationships
      |> Enum.filter(&Map.get(&1, :manual))
      |> Enum.map(& &1.name)

    dsl
    |> Verifier.get_option([:graphql], :paginate_relationship_with, [])
    |> Enum.each(fn {relationship_name, strategy} ->
      cond do
        relationship_name not in many_relationship_names ->
          module = Verifier.get_persisted(dsl, :module)

          raise Spark.Error.DslError,
            module: module,
            path: [:graphql, :paginate_relationship_with],
            message: """
            #{relationship_name} is not a relationship with cardinality many.
            """

        strategy not in @valid_strategies ->
          module = Verifier.get_persisted(dsl, :module)
          choices = Enum.map_join(@valid_strategies, ", ", &inspect/1)

          raise Spark.Error.DslError,
            module: module,
            path: [:graphql, :paginate_relationship_with],
            message: """
            #{inspect(strategy)} is not a valid pagination strategy for relationships.

            Available strategies: #{choices}
            """

        relationship_name in manual_relationship_names and strategy not in [nil, :none] ->
          module = Verifier.get_persisted(dsl, :module)

          raise Spark.Error.DslError,
            module: module,
            path: [:graphql, :paginate_relationship_with],
            message: """
            #{relationship_name} is a manual relationship, which can't be paginated.

            Ash loads a manual relationship for all parents in one call, so it can't apply a limit, offset or page to it.
            """

        true ->
          :ok
      end
    end)
  end
end
