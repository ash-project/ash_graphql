defmodule AshGraphql.Resource.Query do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :action,
    :type,
    :identity,
    :allow_nil?,
    :modify_resolution,
    as_mutation?: false,
    metadata_names: [],
    metadata_types: [],
    show_metadata: nil,
    type_name: nil,
    relay?: false
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
      Override the type name returned by this query. Must be set if the read action has `metadata`.

      To ignore any action metadata, set this to the same type the resource uses, or set `show_metadata` to `[]`.
      To show metadata in the response, choose a new name here, like `:user_with_token` to get a response type that
      includes the additional fields.
      """
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
      Places the query in the `mutations` key instead. The use cases for this are likely very minimal.

      If you have a query that needs to modify the graphql context using `modify_resolution`, then you
      should likely set this as well. A simple example might be a `log_in`, which could be a read
      action on the user that accepts an email/password, and should then set some context in the graphql
      inside of `modify_resolution`. Once in the context, you can see the guide referenced in `modify_resolution`
      for more on setting the session or a cookie with an auth token.
      """
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
                ],
                modify_resolution: [
                  type: :mfa,
                  doc: """
                  An MFA that will be called with the resolution, the query, and the result of the action as the first three arguments (followed by the arguments in the mfa).
                  Must return a new absinthe resolution. This can be used to implement things like setting cookies based on resource actions. A method of using resolution context
                  for that is documented here: https://hexdocs.pm/absinthe_plug/Absinthe.Plug.html#module-before-send

                  *Important* if you are modifying the context, then you should also set `as_mutation?` to true and represent
                  this in your graphql as a mutation. See `as_mutation?` for more.
                  """
                ]
              ]
              |> Spark.OptionsHelpers.merge_schemas(@query_schema, "Shared Query Options")

  @read_one_schema [
                     allow_nil?: [
                       type: :boolean,
                       default: true,
                       doc: "Whether or not the action can return nil."
                     ]
                   ]
                   |> Spark.OptionsHelpers.merge_schemas(@query_schema, "Shared Query Options")

  @list_schema [
                 relay?: [
                   type: :boolean,
                   default: false,
                   doc: """
                   If true, the graphql queries/resolvers for this resource will be built to honor the [relay specification](https://relay.dev/graphql/connections.htm).

                   The two changes that are made currently are:

                   * the type for the resource will implement the `Node` interface
                   * pagination over that resource will behave as a Connection.
                   """
                 ]
               ]
               |> Spark.OptionsHelpers.merge_schemas(@query_schema, "Shared Query Options")

  def get_schema, do: @get_schema
  def read_one_schema, do: @read_one_schema
  def list_schema, do: @list_schema
end
