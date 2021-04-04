defmodule AshGraphql.Resource.Query do
  @moduledoc "Represents a configured query on a resource"
  defstruct [:name, :action, :type, :identity]

  @get_schema [
    name: [
      type: :atom,
      doc: "The name to use for the query.",
      default: :get
    ],
    action: [
      type: :atom,
      doc: "The action to use for the query.",
      required: true
    ],
    identity: [
      type: :atom,
      doc: "The identity to use for looking up the user",
      required: false
    ]
  ]

  @read_one_schema [
    name: [
      type: :atom,
      doc: "The name to use for the query.",
      default: :read_one
    ],
    action: [
      type: :atom,
      doc: "The action to use for the query.",
      required: true
    ]
  ]

  @list_schema [
    name: [
      type: :atom,
      doc: "The name to use for the query.",
      default: :list
    ],
    action: [
      type: :atom,
      doc: "The action to use for the query.",
      required: true
    ]
  ]

  def get_schema, do: @get_schema
  def read_one_schema, do: @read_one_schema
  def list_schema, do: @list_schema
end
