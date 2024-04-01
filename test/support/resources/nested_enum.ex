defmodule AshGraphql.Test.NestedEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:foo, :bar]

  def graphql_type(_), do: :nested_enum
end
