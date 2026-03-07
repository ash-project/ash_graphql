# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.VerifyFieldDependenciesTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource.Verifiers.VerifyFieldDependencies
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
      type :verify_field_deps_base
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:age, :integer, public?: true)
    end

    relationships do
      belongs_to(:related1, __MODULE__, public?: true)
      belongs_to(:related2, __MODULE__, public?: true)
    end
  end

  defp dsl_state do
    BaseResource.spark_dsl_config()
  end

  defp set_graphql_option(dsl, option, value) do
    Transformer.set_option(dsl, [:graphql], option, value)
  end

  describe "show_fields / hide_fields contradiction" do
    test "raises when a field appears in both show_fields and hide_fields" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name, :email])
        |> set_graphql_option(:hide_fields, [:name])

      assert_raise Spark.Error.DslError, ~r/show_fields.*hide_fields/s, fn ->
        VerifyFieldDependencies.verify(dsl)
      end
    end

    test "raises with multiple conflicting fields" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name, :email])
        |> set_graphql_option(:hide_fields, [:name, :email])

      assert_raise Spark.Error.DslError, ~r/\[:email, :name\]/, fn ->
        VerifyFieldDependencies.verify(dsl)
      end
    end

    test "passes when show_fields and hide_fields are disjoint" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name])
        |> set_graphql_option(:hide_fields, [:email])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "passes when only show_fields is set" do
      dsl = set_graphql_option(dsl_state(), :show_fields, [:id, :name])
      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "passes when only hide_fields is set" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:email])
      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "passes when neither is set" do
      assert :ok = VerifyFieldDependencies.verify(dsl_state())
    end
  end

  describe "sortable_fields on hidden fields" do
    test "warns when sortable field is in hide_fields" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:sortable_fields, [:name, :age])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
      assert hd(warnings) =~ "sortable_fields"
    end

    test "warns when sortable field is not in show_fields" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :age])
        |> set_graphql_option(:sortable_fields, [:name, :age])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
    end

    test "no warning when sortable field is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name, :age])
        |> set_graphql_option(:sortable_fields, [:name, :age])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "no warning when sortable_fields is nil" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:name])
      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "filterable_fields on hidden fields" do
    test "warns for bare atom filterable field that is hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:filterable_fields, [:name, :age])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
      assert hd(warnings) =~ "filterable_fields"
    end

    test "warns for keyword tuple filterable field that is hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:filterable_fields, [{:name, [:eq, :in]}, :age])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
    end

    test "no warning when filterable field is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name, :age])
        |> set_graphql_option(:filterable_fields, [:name, :age])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "no warning when filterable_fields is nil" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:name])
      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "field_names on hidden fields" do
    test "warns when renaming a hidden field" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:field_names, name: :display_name)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
      assert hd(warnings) =~ "field_names"
    end

    test "no warning when renaming a visible field" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name])
        |> set_graphql_option(:field_names, name: :display_name)

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "nullable_fields on hidden fields" do
    test "warns when nullable field is hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:nullable_fields, [:name])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
      assert hd(warnings) =~ "nullable_fields"
    end

    test "no warning when nullable field is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name])
        |> set_graphql_option(:nullable_fields, [:name])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "relationships on hidden fields" do
    test "warns when relationship is explicitly listed but hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:related1])
        |> set_graphql_option(:relationships, [:related1])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related1"
      assert hd(warnings) =~ "relationships"
    end

    test "no warning when relationship is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:relationships, [:related1])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "no warning when relationships is nil (default)" do
      dsl = set_graphql_option(dsl_state(), :hide_fields, [:related1])
      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "paginate_relationship_with on hidden fields" do
    test "warns when paginated relationship is hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:related1])
        |> set_graphql_option(:paginate_relationship_with, related1: :keyset)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related1"
      assert hd(warnings) =~ "paginate_relationship_with"
    end

    test "no warning when paginated relationship is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:paginate_relationship_with, related1: :keyset)

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "attribute_input_types on hidden fields" do
    test "warns when attribute with custom input type is hidden" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name])
        |> set_graphql_option(:attribute_input_types, name: :string)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":name"
      assert hd(warnings) =~ "attribute_input_types"
    end

    test "no warning when attribute with custom input type is visible" do
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name])
        |> set_graphql_option(:attribute_input_types, name: :string)

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "excluded from relationships option" do
    test "warns when paginate_relationship_with references excluded relationship" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:paginate_relationship_with, related2: :keyset)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related2"
      assert hd(warnings) =~ "paginate_relationship_with"
      assert hd(warnings) =~ "not included in `relationships`"
    end

    test "warns when filterable_fields bare atom references excluded relationship" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:filterable_fields, [:name, :related2])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related2"
      assert hd(warnings) =~ "filterable_fields"
    end

    test "warns when filterable_fields keyword tuple references excluded relationship" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:filterable_fields, [{:related2, [:eq, :in]}, :name])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related2"
      assert hd(warnings) =~ "filterable_fields"
    end

    test "warns when field_names references excluded relationship" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:field_names, related2: :another_name)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related2"
      assert hd(warnings) =~ "field_names"
    end

    test "warns when nullable_fields references excluded relationship" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:nullable_fields, [:related2])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related2"
      assert hd(warnings) =~ "nullable_fields"
    end

    test "no warning for non-relationship fields in filterable_fields" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:filterable_fields, [:name, :age])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "no warning when relationships is nil (default)" do
      dsl =
        dsl_state()
        |> set_graphql_option(:paginate_relationship_with, related2: :keyset)
        |> set_graphql_option(:filterable_fields, [:related2])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end

    test "no warning when relationship is included" do
      dsl =
        dsl_state()
        |> set_graphql_option(:relationships, [:related1, :related2])
        |> set_graphql_option(:paginate_relationship_with, related2: :keyset)
        |> set_graphql_option(:filterable_fields, [:name, :related2])

      assert :ok = VerifyFieldDependencies.verify(dsl)
    end
  end

  describe "both visibility and relationships gates" do
    test "warns twice when field is both hidden and excluded from relationships" do
      # :related2 is hidden AND not in relationships - two separate issues
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:related2])
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:filterable_fields, [:related2])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 2
      assert Enum.any?(warnings, &(&1 =~ "not visible"))
      assert Enum.any?(warnings, &(&1 =~ "not included in `relationships`"))
    end

    test "warns from visibility when relationship in show_fields is missing but in relationships" do
      # :related1 is in relationships but NOT in show_fields
      dsl =
        dsl_state()
        |> set_graphql_option(:show_fields, [:id, :name])
        |> set_graphql_option(:relationships, [:related1])

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 1
      assert hd(warnings) =~ ":related1"
      assert hd(warnings) =~ "relationships"
      assert hd(warnings) =~ "not visible"
    end
  end

  describe "multiple warnings" do
    test "returns multiple warnings across different options" do
      dsl =
        dsl_state()
        |> set_graphql_option(:hide_fields, [:name, :related1])
        |> set_graphql_option(:sortable_fields, [:name])
        |> set_graphql_option(:filterable_fields, [:name])
        |> set_graphql_option(:nullable_fields, [:name])
        |> set_graphql_option(:field_names, name: :display_name)
        |> set_graphql_option(:relationships, [:related1])
        |> set_graphql_option(:paginate_relationship_with, related1: :keyset)
        |> set_graphql_option(:attribute_input_types, name: :string)

      assert {:warn, warnings} = VerifyFieldDependencies.verify(dsl)
      assert length(warnings) == 7

      assert Enum.any?(warnings, &(&1 =~ "sortable_fields"))
      assert Enum.any?(warnings, &(&1 =~ "filterable_fields"))
      assert Enum.any?(warnings, &(&1 =~ "nullable_fields"))
      assert Enum.any?(warnings, &(&1 =~ "field_names"))
      assert Enum.any?(warnings, &(&1 =~ "relationships"))
      assert Enum.any?(warnings, &(&1 =~ "paginate_relationship_with"))
      assert Enum.any?(warnings, &(&1 =~ "attribute_input_types"))
    end
  end
end
