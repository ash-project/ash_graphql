# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.DefaultTypesTest do
  use ExUnit.Case, async: true

  defmodule OpaqueInteger do
    @moduledoc false
    use Ash.Type

    @impl true
    def storage_type, do: :integer

    @impl true
    def cast_input(value, constraints),
      do: Ash.Type.Integer.cast_input(value, constraints)

    @impl true
    def cast_stored(value, constraints),
      do: Ash.Type.Integer.cast_stored(value, constraints)

    @impl true
    def dump_to_native(value, constraints),
      do: Ash.Type.Integer.dump_to_native(value, constraints)
  end

  defmodule Widget do
    @moduledoc false
    use Ash.Resource,
      domain: AshGraphql.DefaultTypesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    attributes do
      uuid_primary_key(:id)

      attribute :value, AshGraphql.DefaultTypesTest.OpaqueInteger do
        public?(true)
      end

      attribute :overridden, AshGraphql.DefaultTypesTest.OpaqueInteger do
        public?(true)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create])
    end

    graphql do
      type :default_types_widget

      attribute_types overridden: :integer
      attribute_input_types overridden: :integer

      queries do
        get :get_widget, :read
      end

      mutations do
        create :create_widget, :create
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, otp_app: :ash_graphql, extensions: [AshGraphql.Domain]

    resources do
      resource(AshGraphql.DefaultTypesTest.Widget)
    end
  end

  defmodule Schema do
    @moduledoc false
    use Absinthe.Schema

    use AshGraphql,
      domains: [AshGraphql.DefaultTypesTest.Domain],
      default_types: [{AshGraphql.DefaultTypesTest.OpaqueInteger, :string}],
      default_input_types: [{AshGraphql.DefaultTypesTest.OpaqueInteger, :string}]

    query do
    end

    mutation do
    end
  end

  test "a read with schema default_types works" do
    widget =
      Widget
      |> Ash.Changeset.for_create(:create, value: 1)
      |> Ash.create!()

    resp =
      """
      query GetWidget($id: ID!) {
        getWidget(id: $id) {
          value
        }
      }
      """
      |> Absinthe.run(Schema, variables: %{"id" => widget.id})

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{data: %{"getWidget" => %{"value" => "1"}}} = result
  end

  test "a create with schema default_input_types works" do
    resp =
      """
      mutation CreateWidget($input: CreateWidgetInput) {
        createWidget(input: $input) {
          result {
            value
          }
        }
      }
      """
      |> Absinthe.run(Schema, variables: %{"input" => %{"value" => "3"}})

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{data: %{"createWidget" => %{"result" => %{"value" => "3"}}}} = result
  end

  test "resource attribute_types and attribute_input_types override schema defaults" do
    widget =
      Widget
      |> Ash.Changeset.for_create(:create, overridden: 2)
      |> Ash.create!()

    resp =
      """
      query GetWidget($id: ID!) {
        getWidget(id: $id) {
          overridden
        }
      }
      """
      |> Absinthe.run(Schema, variables: %{"id" => widget.id})

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{data: %{"getWidget" => %{"overridden" => 2}}} = result

    resp =
      """
      mutation CreateWidget($input: CreateWidgetInput) {
        createWidget(input: $input) {
          result {
            overridden
          }
        }
      }
      """
      |> Absinthe.run(Schema, variables: %{"input" => %{"overridden" => 4}})

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{data: %{"createWidget" => %{"result" => %{"overridden" => 4}}}} = result
  end

  test "invalid schema default_types are rejected" do
    assert_raise ArgumentError, ~r/Invalid `default_types` configuration/, fn ->
      AshGraphql.validate_default_types!("invalid", :default_types)
    end
  end
end
