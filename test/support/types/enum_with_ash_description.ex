defmodule AshGraphql.Test.EnumWithAshDescription do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      fizz: "A fizz",
      buzz: "A buzz"
    ]

  def graphql_type(_), do: :enum_with_ash_description
end
