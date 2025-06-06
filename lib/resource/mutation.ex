defmodule AshGraphql.Resource.Mutation do
  @moduledoc "Represents a configured mutation on a resource"
  defstruct [
    :name,
    :action,
    :type,
    :identity,
    :read_action,
    :resource,
    :upsert?,
    :upsert_identity,
    :modify_resolution,
    :relay_id_translations,
    :description,
    args: [],
    hide_inputs: [],
    meta: []
  ]

  @mutation_schema [
    name: [
      type: :atom,
      doc: "The name to use for the mutation.",
      default: :get
    ],
    action: [
      type: :atom,
      doc: "The action to use for the mutation.",
      required: true
    ],
    description: [
      type: :string,
      doc:
        "The mutation description that gets shown in the Graphql schema. If not provided, the action description will be used."
    ],
    relay_id_translations: [
      type: :keyword_list,
      doc: """
      A keyword list indicating arguments or attributes that have to be translated from global Relay IDs to internal IDs. See the [Relay guide](/documentation/topics/relay.md#translating-relay-global-ids-passed-as-arguments) for more.
      """,
      default: []
    ],
    args: [
      type: {:list, :atom},
      doc: """
      A list of action attributes or arguments that should get their own arguments in the mutation instead of being passed in an input object.
      """
    ],
    hide_inputs: [
      type: {:list, :atom},
      doc: "A list of inputs to hide from the mutation."
    ],
    modify_resolution: [
      type: :mfa,
      doc: """
      An MFA that will be called with the resolution, the query, and the result of the action as the first three arguments. See the [the guide](/documentation/topics/modifying-the-resolution.html) for more.
      """
    ],
    meta: [
      type: :keyword_list,
      doc: "A keyword list of metadata for the mutation.",
      default: []
    ]
  ]

  @create_schema [
                   upsert?: [
                     type: :boolean,
                     default: false,
                     doc:
                       "Whether or not to use the `upsert?: true` option when calling `YourDomain.create/2`."
                   ],
                   upsert_identity: [
                     type: :atom,
                     default: false,
                     doc: "Which identity to use for the upsert"
                   ]
                 ]
                 |> Spark.Options.merge(@mutation_schema, "Shared Mutation Options")

  @update_schema [
                   identity: [
                     type: :atom,
                     doc: """
                     The identity to use to fetch the record to be updated. Use `false` if no identity is required.
                     """
                   ],
                   read_action: [
                     type: :atom,
                     doc:
                       "The read action to use to fetch the record to be updated. Defaults to the primary read action."
                   ]
                 ]
                 |> Spark.Options.merge(@mutation_schema, "Shared Mutation Options")

  @destroy_schema [
                    identity: [
                      type: :atom,
                      doc: """
                      The identity to use to fetch the record to be destroyed. Use `false` if no identity is required.
                      """
                    ],
                    read_action: [
                      type: :atom,
                      doc:
                        "The read action to use to fetch the record to be destroyed. Defaults to the primary read action."
                    ]
                  ]
                  |> Spark.Options.merge(@mutation_schema, "Shared Mutation Options")

  def create_schema, do: @create_schema
  def update_schema, do: @update_schema
  def destroy_schema, do: @destroy_schema
end
