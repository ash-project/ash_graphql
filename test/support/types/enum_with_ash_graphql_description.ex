defmodule AshGraphql.Test.EnumWithAshGraphqlDescription do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      foo: "This should get ignored by AshGraphQL",
      bar: "This too",
      no_description: "And also this"
    ]

  def graphql_type, do: :enum_with_ash_graphql_description

  def graphql_describe_enum_value(:foo), do: "A foo"
  def graphql_describe_enum_value(:bar), do: "A bar"
  def graphql_describe_enum_value(_), do: nil
end
