# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.VerifyFilterHandlersTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource.Verifiers.VerifyFilterHandlers
  alias Spark.Dsl.Transformer

  defmodule TestDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule Calculation do
    use Ash.Resource.Calculation, type: :string

    @impl true
    def calculate(records, _opts, _context), do: Enum.map(records, fn _ -> "value" end)
  end

  defmodule BaseResource do
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshGraphql.Resource]

    graphql do
      type :verify_filter_handlers_base
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    calculations do
      calculate(:public_calc, :string, Calculation) do
        public?(true)
      end

      calculate(:private_calc, :string, Calculation)
    end
  end

  defp dsl_state, do: BaseResource.spark_dsl_config()

  defp set_filter_handlers(dsl, value) do
    Transformer.set_option(dsl, [:graphql], :filter_handlers, value)
  end

  defp handler_config(extra \\ []) do
    Keyword.merge([type: :string, handler: {SomeModule, :some_fun, []}], extra)
  end

  test "accepts an attribute" do
    dsl = set_filter_handlers(dsl_state(), name: handler_config())

    assert :ok = VerifyFilterHandlers.verify(dsl)
  end

  test "accepts a public calculation" do
    dsl = set_filter_handlers(dsl_state(), public_calc: handler_config())

    assert :ok = VerifyFilterHandlers.verify(dsl)
  end

  test "raises for a private calculation" do
    dsl = set_filter_handlers(dsl_state(), private_calc: handler_config())

    assert_raise Spark.Error.DslError, ~r/`:private_calc`.*filter_handlers/s, fn ->
      VerifyFilterHandlers.verify(dsl)
    end
  end

  test "raises for an unknown field" do
    dsl = set_filter_handlers(dsl_state(), nonexistent: handler_config())

    assert_raise Spark.Error.DslError, ~r/`:nonexistent`.*filter_handlers/s, fn ->
      VerifyFilterHandlers.verify(dsl)
    end
  end
end
