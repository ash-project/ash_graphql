defmodule UnionRelation do
  @moduledoc false
  alias AshGraphql.Test.{Comment, SponsoredComment}

  @types [
    comment: [
      type: :struct,
      constraints: [instance_of: Comment],
      tag: :type,
      tag_value: :comment
    ],
    sponsored_comment: [
      type: :struct,
      constraints: [instance_of: SponsoredComment],
      tag: :type,
      tag_value: :sponsored
    ]
  ]

  @structs_to_names Keyword.new(@types, fn {key, value} ->
                      {value[:constraints][:instance_of], key}
                    end)

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: @types
    ]

  def struct_to_name(%struct{}), do: @structs_to_names[struct]

  def graphql_type(_), do: :post_comments

  def graphql_unnested_unions(_), do: Keyword.keys(@types)
end
