defmodule AshGraphql.Resource.ManagedRelationship do
  @moduledoc "Represents a managed relationship configuration on a mutation"

  defstruct [:argument, :action, :types, :type_name]

  @schema [
    argument: [
      type: :atom,
      doc: "The argument for which an input object should be derived.",
      required: true
    ],
    action: [
      type: :atom,
      doc: "The action that accepts the argument"
    ],
    type_name: [
      type: :atom,
      doc: """
      The name of the input object that will be derived. Defaults to `<action_type>_<resource>_<argument_name>_input`

      Because multiple actions could potentially be managing the same relationship, it isn't suficcient to
      default to something like `<resource>_<relationship>_input`. Additionally, Ash doesn't expose resource
      action names by default, meaning that there is no automatic way to ensure that all
      of these have a default name that will always be unique. If you have multiple actions of the same
      type that manage a relationship with an argument of the same name, you will get a compile-time error.
      """
    ],
    types: [
      type: :any,
      doc: """
      A keyword list of field names to their graphql type identifiers.

      Since managed relationships can ultimately call multiple actions, there is the possibility
      of field type conflicts. Use this to determine the type of fields and remove the conflict warnings.
      """
    ]
  ]

  def schema, do: @schema
end
