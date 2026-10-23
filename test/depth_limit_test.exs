# SPDX-FileCopyrightText: 2026 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.DepthLimitTest do
  use ExUnit.Case, async: false

  defmodule Product do
    use Ash.Resource,
      domain: AshGraphql.DepthLimitTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    graphql do
      type :depth_limit_product
      depth_limit 2
      paginate_relationship_with variants: :relay

      queries do
        list :list_depth_limit_products, :read
      end

      mutations do
        create :create_depth_limit_product, :create
      end
    end

    actions do
      default_accept(:*)
      defaults([:create])

      read :read do
        primary?(true)
        pagination(keyset?: true, required?: false)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:variants, AshGraphql.DepthLimitTest.Variant, public?: true)
    end
  end

  defmodule Variant do
    use Ash.Resource,
      domain: AshGraphql.DepthLimitTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    graphql do
      type :depth_limit_variant

      queries do
        list :list_depth_limit_variants, :read
      end
    end

    actions do
      default_accept(:*)
      defaults([:create])

      read :read do
        primary?(true)
        pagination(keyset?: true, required?: false)
      end
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:product, Product, public?: true, attribute_writable?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [AshGraphql.Domain], validate_config_inclusion?: false

    graphql do
      authorize?(false)
    end

    resources do
      resource(Product)
      resource(Variant)
    end
  end

  defmodule Schema do
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.DepthLimitTest.Domain]

    query do
    end

    mutation do
    end
  end

  @depth_error "Query nests relationships deeper than the depth limit of 2"

  setup do
    product = Ash.create!(Product, %{name: "Shirt"})
    Ash.create!(Variant, %{product_id: product.id})

    on_exit(fn ->
      Ash.DataLayer.Ets.stop(Product)
      Ash.DataLayer.Ets.stop(Variant)
    end)

    :ok
  end

  defp run(document), do: Absinthe.run(document, Schema)

  test "a query nesting as many relationships as the limit is allowed" do
    assert {:ok, %{data: data} = result} =
             run("""
             {
               listDepthLimitProducts {
                 results {
                   variants { edges { node { product { name } } } }
                 }
               }
             }
             """)

    refute Map.has_key?(result, :errors)

    assert %{
             "listDepthLimitProducts" => %{
               "results" => [
                 %{
                   "variants" => %{"edges" => [%{"node" => %{"product" => %{"name" => "Shirt"}}}]}
                 }
               ]
             }
           } = data
  end

  test "a query nesting more relationships than the limit is refused" do
    assert {:ok, %{data: %{"listDepthLimitProducts" => nil}, errors: [error]}} =
             run("""
             {
               listDepthLimitProducts {
                 results {
                   variants { edges { node { product { variants { edges { node { id } } } } } } }
                 }
               }
             }
             """)

    assert error.message == @depth_error
  end

  test "relationships inside named and inline fragments count" do
    assert {:ok, %{errors: [%{message: @depth_error}]}} =
             run("""
             {
               listDepthLimitProducts {
                 results { variants { edges { node { ...VariantFields } } } }
               }
             }

             fragment VariantFields on DepthLimitVariant {
               product { variants { edges { node { id } } } }
             }
             """)

    assert {:ok, %{errors: [%{message: @depth_error}]}} =
             run("""
             {
               listDepthLimitProducts {
                 results {
                   variants {
                     edges {
                       node {
                         ... on DepthLimitVariant { product { variants { edges { node { id } } } } }
                       }
                     }
                   }
                 }
               }
             }
             """)
  end

  test "skipped fields don't count" do
    assert {:ok, result} =
             run("""
             {
               listDepthLimitProducts {
                 results {
                   variants {
                     edges {
                       node { product { variants @skip(if: true) { edges { node { id } } } } }
                     }
                   }
                 }
               }
             }
             """)

    refute Map.has_key?(result, :errors)
  end

  test "a mutation whose result nests too deep is refused before it runs" do
    assert {:ok, %{errors: [%{message: @depth_error}]}} =
             run("""
             mutation {
               createDepthLimitProduct(input: {name: "Hat"}) {
                 result {
                   variants { edges { node { product { variants { edges { node { id } } } } } } }
                 }
               }
             }
             """)

    assert [%{name: "Shirt"}] = Ash.read!(Product)
  end

  test "resources without a depth limit aren't limited" do
    assert {:ok, result} =
             run("""
             {
               listDepthLimitVariants {
                 results {
                   product { variants { edges { node { product { variants { edges { node { id } } } } } } } }
                 }
               }
             }
             """)

    refute Map.has_key?(result, :errors)
  end
end
