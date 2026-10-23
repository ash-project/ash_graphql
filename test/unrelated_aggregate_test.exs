# SPDX-FileCopyrightText: 2026 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.UnrelatedAggregateTest do
  use ExUnit.Case, async: false

  defmodule OrderLine do
    use Ash.Resource,
      domain: AshGraphql.UnrelatedAggregateTest.Domain,
      data_layer: Ash.DataLayer.Ets

    actions do
      default_accept(:*)
      defaults([:read, :create])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:product_id, :uuid, public?: true)
      attribute(:quantity, :integer, public?: true, allow_nil?: false)
    end
  end

  defmodule Product do
    use Ash.Resource,
      domain: AshGraphql.UnrelatedAggregateTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    graphql do
      type :unrelated_aggregate_product

      queries do
        list :list_unrelated_aggregate_products, :read, paginate_with: nil
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create])
    end

    attributes do
      uuid_primary_key(:id)
      # Shares its name, but not its type, with the field the aggregates are over.
      attribute(:quantity, :string, public?: true)
    end

    aggregates do
      sum :units_sold, OrderLine, :quantity do
        public?(true)
        filter(expr(product_id == parent(id)))
      end

      list :line_quantities, OrderLine, :quantity do
        public?(true)
        filter(expr(product_id == parent(id)))
        sort(quantity: :asc)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [AshGraphql.Domain], validate_config_inclusion?: false

    graphql do
      authorize?(false)
    end

    resources do
      resource(OrderLine)
      resource(Product)
    end
  end

  defmodule Schema do
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.UnrelatedAggregateTest.Domain]

    query do
    end
  end

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "unrelated aggregates are typed from the aggregated resource's field" do
    {:ok, %{data: %{"__type" => %{"fields" => fields}}}} =
      Absinthe.run(
        """
        {
          __type(name: "UnrelatedAggregateProduct") {
            fields { name type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } }
          }
        }
        """,
        Schema
      )

    types = Map.new(fields, &{&1["name"], &1["type"]})

    assert %{"kind" => "SCALAR", "name" => "Int"} = types["unitsSold"]

    assert %{
             "kind" => "NON_NULL",
             "ofType" => %{
               "kind" => "LIST",
               "ofType" => %{
                 "kind" => "NON_NULL",
                 "ofType" => %{"kind" => "SCALAR", "name" => "Int"}
               }
             }
           } = types["lineQuantities"]
  end

  test "unrelated aggregates can be read, filtered and sorted" do
    product = Ash.create!(Product, %{quantity: "6-pack"})
    other_product = Ash.create!(Product, %{quantity: "single"})

    for quantity <- [3, 4] do
      Ash.create!(OrderLine, %{product_id: product.id, quantity: quantity})
    end

    Ash.create!(OrderLine, %{product_id: other_product.id, quantity: 1})

    assert {:ok, %{data: %{"listUnrelatedAggregateProducts" => results}} = result} =
             Absinthe.run(
               """
               {
                 listUnrelatedAggregateProducts(
                   filter: {unitsSold: {greaterThan: 0}}
                   sort: [{field: UNITS_SOLD, order: DESC}]
                 ) {
                   quantity
                   unitsSold
                   lineQuantities
                 }
               }
               """,
               Schema
             )

    refute Map.has_key?(result, :errors)

    assert results == [
             %{"quantity" => "6-pack", "unitsSold" => 7, "lineQuantities" => [3, 4]},
             %{"quantity" => "single", "unitsSold" => 1, "lineQuantities" => [1]}
           ]
  end
end
