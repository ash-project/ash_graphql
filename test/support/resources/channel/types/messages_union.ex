defmodule AshGraphql.Test.MessageUnion do
  @moduledoc false

  @types [
    text: [
      type: :struct,
      constraints: [instance_of: AshGraphql.Test.TextMessage],
      tag: :type,
      tag_value: :text_message
    ],
    image: [
      type: :struct,
      constraints: [instance_of: AshGraphql.Test.ImageMessage],
      tag: :type,
      tag_value: :image_message
    ]
  ]

  @structs_to_names Keyword.new(@types, fn {key, _value} -> {key, key} end)

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: @types
    ]

  def struct_to_name(%_struct{} = s), do: @structs_to_names[s.type]

  @impl true
  def graphql_type(_), do: :message

  @impl true
  def graphql_unnested_unions(_), do: Keyword.keys(@types)
end
