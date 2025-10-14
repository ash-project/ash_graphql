# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.RequirePkeyDelimiter do
  # Ensures that the resource has a primary key called `id`
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  def verify(dsl) do
    if Verifier.get_persisted(dsl, :embedded?) do
      :ok
    else
      primary_key =
        dsl
        |> Verifier.get_entities([:attributes])
        |> Enum.filter(& &1.primary_key?)

      case primary_key do
        [] ->
          :ok

        [_single] ->
          :ok

        [_ | _] ->
          if Verifier.get_persisted(dsl, :primary_key) do
            :ok
          else
            module = Verifier.get_persisted(dsl, :module)

            raise Spark.Error.DslError,
              module: module,
              path: [:graphql, :primary_key_delimiter],
              message:
                "AshGraphql requires a `primary_key_delimiter` to be set for composite primary keys."
          end
      end
    end
  end
end
