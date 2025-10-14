# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.ManagedRelationship do
  @moduledoc "Represents a managed relationship configuration on a mutation"

  defstruct [
    :argument,
    :action,
    :types,
    :type_name,
    :lookup_with_primary_key?,
    :lookup_identities,
    :ignore?,
    :__spark_metadata__
  ]

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
    lookup_with_primary_key?: [
      type: :boolean,
      doc: """
      If the managed_relationship has `on_lookup` behavior, this option determines whether or not the primary key is provided in the input object for looking up.
      """
    ],
    lookup_identities: [
      type: {:list, :atom},
      doc: """
      Determines which identities are provided in the input object for looking up, if there is `on_lookup` behavior. Defalts to the `use_identities` option.
      """
    ],
    type_name: [
      type: :atom,
      doc: """
      The name of the input object that will be derived. Defaults to `<action_type>_<resource>_<argument_name>_input`
      """
    ],
    types: [
      type: :any,
      doc: """
      A keyword list of field names to their graphql type identifiers.
      """
    ],
    ignore?: [
      type: :boolean,
      default: false,
      doc: """
      Use this to ignore a given managed relationship, preventing `auto? true` from deriving a type for it.
      """
    ]
  ]

  def schema, do: @schema
end
