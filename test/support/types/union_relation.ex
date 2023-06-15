defmodule UnionRelation do
  alias AshGraphql.Test.{SponsoredComment, Comment}

  @types [
    comment: [
      type: Comment,
      tag: :type,
      tag_value: :comment
    ],
    sponsored_comment: [
      type: SponsoredComment,
      tag: :type,
      tag_value: :sponsored
    ]
  ]

  @structs_to_names Keyword.new(@types, fn {key, value} -> {value[:type], key} end)

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: @types
    ]

  def struct_to_name(%struct{}), do: @structs_to_names[struct]

  def graphql_type(_), do: :post_comments

  # You'll want this likely
  def graphql_unnested_unions(_), do: Keyword.keys(@types)
end
