defmodule AshGraphql.Test.NestedEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:foo, :bar]

  def graphql_type, do: :nested_enum
end
