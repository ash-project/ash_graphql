defmodule AshGraphql.Test.NestedEnum do
  use Ash.Type.Enum, values: [:foo, :bar]

  def graphql_type(), do: :nested_enum
end
