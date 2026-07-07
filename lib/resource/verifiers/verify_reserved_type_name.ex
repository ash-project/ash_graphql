# SPDX-FileCopyrightText: 2026 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyReservedTypeName do
  # Ensures that `:subscription` is not used as a resource graphql type
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  def verify(dsl) do
    module = Verifier.get_persisted(dsl, :module)
    type = AshGraphql.Resource.Info.type(dsl)

    if type == :subscription do
      raise Spark.Error.DslError,
        module: module,
        path: [:graphql, :type],
        message: """
        `:subscription` is reserved and cannot be used as a resource graphql type.
        It conflicts with GraphQL's subscription root schema entry.
        """
    end

    :ok
  end
end
