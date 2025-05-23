defmodule AshGraphql.Resource.Query do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :action,
    :type,
    :identity,
    :allow_nil?,
    :resource,
    :modify_resolution,
    :relay_id_translations,
    :description,
    :complexity,
    as_mutation?: false,
    hide_inputs: [],
    metadata_names: [],
    metadata_types: [],
    paginate_with: :keyset,
    show_metadata: nil,
    type_name: nil,
    relay?: false,
    meta: []
  ]

  @query_schema [
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
    type_name: [
      type: :atom,
      doc: """
      Override the type name returned by this query. Must be set if the read action has `metadata` that is not hidden via the `show_metadata` key.
      """
    ],
    description: [
      type: :string,
      doc:
        "The query description that gets shown in the Graphql schema. If not provided, the action description will be used."
    ],
    metadata_names: [
      type: :keyword_list,
      default: [],
      doc: "Name overrides for metadata fields on the read action."
    ],
    metadata_types: [
      type: :keyword_list,
      default: [],
      doc: "Type overrides for metadata fields on the read action."
    ],
    show_metadata: [
      type: {:list, :atom},
      doc: "The metadata attributes to show. Defaults to all."
    ],
    as_mutation?: [
      type: :boolean,
      default: false,
      doc: """
      Places the query in the `mutations` key instead. Not typically necessary, but is often paired with `as_mutation?`. See the [the guide](/documentation/topics/modifying-the-resolution.html) for more.
      """
    ],
    relay_id_translations: [
      type: :keyword_list,
      doc: """
      A keyword list indicating arguments or attributes that have to be translated from global Relay IDs to internal IDs. See the [Relay guide](/documentation/topics/relay.md#translating-relay-global-ids-passed-as-arguments) for more.
      """,
      default: []
    ],
    hide_inputs: [
      type: {:list, :atom},
      doc: "A list of inputs to hide from the mutation.",
      default: []
    ],
    complexity: [
      type: :mod_arg,
      doc: """
      An {module, function} that will be called with the arguments and complexity value of the child fields query. It should return the complexity of this query.
      """,
      default: {AshGraphql.Graphql.Resolver, :query_complexity}
    ],
    modify_resolution: [
      type: :mfa,
      doc: """
      An MFA that will be called with the resolution, the query, and the result of the action as the first three arguments. See the [the guide](/documentation/topics/modifying-the-resolution.html) for more.
      """
    ],
    meta: [
      type: :keyword_list,
      doc: "A keyword list of metadata for the query.",
      default: []
    ]
  ]

  @get_schema [
                identity: [
                  type: :atom,
                  doc:
                    "The identity to use for looking up the record. Pass `false` to not use an identity.",
                  required: false
                ],
                allow_nil?: [
                  type: :boolean,
                  default: true,
                  doc: "Whether or not the action can return nil."
                ]
              ]
              |> Spark.Options.merge(@query_schema, "Shared Query Options")

  @read_one_schema [
                     allow_nil?: [
                       type: :boolean,
                       default: true,
                       doc: "Whether or not the action can return nil."
                     ]
                   ]
                   |> Spark.Options.merge(@query_schema, "Shared Query Options")

  @list_schema [
                 relay?: [
                   type: :boolean,
                   default: false,
                   doc: """
                   If true, the graphql queries/resolvers for this resource will be built to honor the relay specification. See [the relay guide](/documentation/topics/relay.html) for more.
                   """
                 ],
                 paginate_with: [
                   type: {:one_of, [:keyset, :offset, nil]},
                   default: :keyset,
                   doc: """
                   Determine the pagination strategy to use, if multiple are available. If `nil`, no pagination is applied, otherwise the given strategy is used.
                   """
                 ]
               ]
               |> Spark.Options.merge(@query_schema, "Shared Query Options")

  def get_schema, do: @get_schema
  def read_one_schema, do: @read_one_schema
  def list_schema, do: @list_schema
end
