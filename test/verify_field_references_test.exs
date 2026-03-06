# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.VerifyFieldReferencesTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource.Verifiers.VerifyFieldReferences
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
      type :verify_field_ref_base
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:hidden, :string, public?: true)
    end

    relationships do
      belongs_to(:related, __MODULE__, public?: true)
    end
  end

  defp dsl_state do
    BaseResource.spark_dsl_config()
  end

  defp set_graphql_option(dsl, option, value) do
    Transformer.set_option(dsl, [:graphql], option, value)
  end

  describe "show_fields" do
    test "raises for unknown field" do
      dsl = set_graphql_option(dsl_state(), :show_fields, [:id, :nonexistent])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:nonexistent`.*show_fields/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid fields" do
      dsl = set_graphql_option(dsl_state(), :show_fields, [:id, :name])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "hide_fields" do
    test "raises for unknown field" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:nonexistent])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:nonexistent`.*hide_fields/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid fields" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:name])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "field_names" do
    test "raises for unknown field key" do
      dsl = set_graphql_option(dsl_state(), :field_names, nonexistent: :renamed)

      assert_raise Spark.Error.DslError, ~r/Unknown field `:nonexistent`.*field_names/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid field keys" do
      dsl = set_graphql_option(dsl_state(), :field_names, name: :display_name)
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "sortable_fields" do
    test "raises for unknown field" do
      dsl = set_graphql_option(dsl_state(), :sortable_fields, [:nonexistent])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:nonexistent`.*sortable_fields/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "raises for relationship name" do
      dsl = set_graphql_option(dsl_state(), :sortable_fields, [:related])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:related`.*sortable_fields/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid fields" do
      dsl = set_graphql_option(dsl_state(), :sortable_fields, [:name])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "filterable_fields" do
    test "raises for unknown bare atom field" do
      dsl = set_graphql_option(dsl_state(), :filterable_fields, [:nonexistent])

      assert_raise Spark.Error.DslError,
                   ~r/Unknown field `:nonexistent`.*filterable_fields/s,
                   fn ->
                     VerifyFieldReferences.verify(dsl)
                   end
    end

    test "raises for unknown keyword field" do
      dsl = set_graphql_option(dsl_state(), :filterable_fields, nonexistent: [:eq])

      assert_raise Spark.Error.DslError,
                   ~r/Unknown field `:nonexistent`.*filterable_fields/s,
                   fn ->
                     VerifyFieldReferences.verify(dsl)
                   end
    end

    test "passes for valid fields including relationships" do
      dsl = set_graphql_option(dsl_state(), :filterable_fields, [:name, :related])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end

    test "passes for valid keyword fields" do
      dsl = set_graphql_option(dsl_state(), :filterable_fields, [:name, id: [:eq]])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "nullable_fields" do
    test "raises for unknown field" do
      dsl = set_graphql_option(dsl_state(), :nullable_fields, [:nonexistent])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:nonexistent`.*nullable_fields/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid fields" do
      dsl = set_graphql_option(dsl_state(), :nullable_fields, [:name])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end
  end

  describe "relationships option" do
    test "raises for non-relationship field" do
      dsl = set_graphql_option(dsl_state(), :relationships, [:name])

      assert_raise Spark.Error.DslError, ~r/Unknown field `:name`.*relationships/s, fn ->
        VerifyFieldReferences.verify(dsl)
      end
    end

    test "passes for valid relationship" do
      dsl = set_graphql_option(dsl_state(), :relationships, [:related])
      assert :ok = VerifyFieldReferences.verify(dsl)
    end

    test "skips validation when not explicitly set" do
      assert :ok = VerifyFieldReferences.verify(dsl_state())
    end
  end
end
