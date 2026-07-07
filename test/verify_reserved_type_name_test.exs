# SPDX-FileCopyrightText: 2026 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.VerifyReservedTypeNameTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource.Verifiers.VerifyReservedTypeName
  alias Spark.Dsl.Transformer

  defmodule TestDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule BaseResource do
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshGraphql.Resource]

    graphql do
      # any valid, non-reserved name
      type :billing_subscription
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:plan, :string, public?: true)
    end
  end

  defp dsl_state do
    BaseResource.spark_dsl_config()
  end

  defp set_graphql_option(dsl, option, value) do
    Transformer.set_option(dsl, [:graphql], option, value)
  end

  test "raises when graphql type is :subscription" do
    dsl = set_graphql_option(dsl_state(), :type, :subscription)

    assert_raise Spark.Error.DslError, ~r/reserved/s, fn ->
      VerifyReservedTypeName.verify(dsl)
    end
  end

  test "passes for non-reserved graphql types" do
    assert :ok = VerifyReservedTypeName.verify(dsl_state())
  end
end
