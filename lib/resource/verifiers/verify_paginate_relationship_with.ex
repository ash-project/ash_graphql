# SPDX-FileCopyrightText: 2020 Zach Daniel
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
    many_relationship_names =
      dsl
      |> Verifier.get_entities([:relationships])
      |> Enum.filter(&(&1.cardinality == :many))
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

        true ->
          :ok
      end
    end)
  end
end
