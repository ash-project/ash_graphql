defmodule AshGraphql.NotationTest do
  use ExUnit.Case, async: false

  test "imports query fields" do
    assert AshGraphql.NotationTest.DomainSchema.__absinthe_type__(:query).fields[:get_comment]
  end

  test "imports mutation fields" do
    assert AshGraphql.NotationTest.DomainSchema.__absinthe_type__(:mutation).fields[
             :create_comment
           ]
  end

  test "imports subscription fields" do
    assert AshGraphql.NotationTest.DomainSchema.__absinthe_type__(:subscription).fields[
             :domain_pubsub_subscription
           ]
  end

  test "registers resource types" do
    assert AshGraphql.NotationTest.DomainSchema.__absinthe_type__(:comment)
    assert AshGraphql.NotationTest.DomainSchema.__absinthe_type__(:mutation_error)
  end

  test "exposes container metadata" do
    assert Enum.all?(AshGraphql.NotationTest.DomainNotation.query_containers(), &is_atom/1)
    assert Enum.all?(AshGraphql.NotationTest.DomainNotation.mutation_containers(), &is_atom/1)
    assert Enum.all?(AshGraphql.NotationTest.DomainNotation.subscription_containers(), &is_atom/1)
  end

  test "defines union resolvers" do
    assert function_exported?(
             AshGraphql.NotationTest.DomainNotation,
             :resolve_gql_union_uniontype,
             2
           )
  end

  test "marks modules as ash graphql schemas" do
    assert AshGraphql.NotationTest.DomainNotation.ash_graphql_schema?()
  end

  test "merges queries from multiple notation modules with decimal fields" do
    query_fields = AshGraphql.NotationTest.DecimalSchema.__absinthe_type__(:query).fields

    assert Map.has_key?(query_fields, :get_decimal_resource_one)
    assert Map.has_key?(query_fields, :get_decimal_resource_two)

    assert AshGraphql.NotationTest.DecimalSchema.__absinthe_type__(:decimal_resource_one).fields[
             :amount
           ].type ==
             :decimal

    assert AshGraphql.NotationTest.DecimalSchema.__absinthe_type__(:decimal_resource_two).fields[
             :amount
           ].type ==
             :decimal
  end
end
