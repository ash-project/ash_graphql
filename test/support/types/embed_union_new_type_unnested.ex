defmodule AshGraphql.Types.EmbedUnionNewTypeUnnested do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        foo: [
          type: Foo,
          tag: :type,
          tag_value: :foo
        ],
        bar: [
          type: Bar,
          tag: :type,
          tag_value: :bar
        ]
      ]
    ]

  def graphql_type, do: :foo_bar_unnested

  def graphql_unnested_unions(_), do: [:foo, :bar]
end
