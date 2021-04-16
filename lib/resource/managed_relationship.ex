defmodule AshGraphql.Resource.ManagedRelationship do
  @moduledoc "Represents a managed relationship configuration on a mutation"

  defstruct [:argument, :action, :types]

  @schema [
    argument: [
      type: :atom,
      doc: "The argument for which an input object should be derived.",
      required: true
    ],
    action: [
      type: :atom,
      doc: "The action that accepts the argument"
    ]
  ]

  def schema, do: @schema
end
