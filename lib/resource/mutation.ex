defmodule AshGraphql.Resource.Mutation do
  @moduledoc "Represents a configured mutation on a resource"
  defstruct [:name, :action, :type]

  @create_schema [
    name: [
      type: :atom,
      doc: "The name to use for the mutation.",
      default: :get
    ],
    action: [
      type: :atom,
      doc: "The action to use for the mutation.",
      required: true
    ]
  ]

  @update_schema [
    name: [
      type: :atom,
      doc: "The name to use for the mutation.",
      default: :get
    ],
    action: [
      type: :atom,
      doc: "The action to use for the mutation.",
      required: true
    ]
  ]

  @destroy_schema [
    name: [
      type: :atom,
      doc: "The name to use for the mutation.",
      default: :get
    ],
    action: [
      type: :atom,
      doc: "The action to use for the mutation.",
      required: true
    ]
  ]

  def create_schema, do: @create_schema
  def update_schema, do: @update_schema
  def destroy_schema, do: @destroy_schema
end
