defmodule AshGraphql.Domain do
  @graphql %Spark.Dsl.Section{
    name: :graphql,
    describe: """
    Global configuration for graphql
    """,
    examples: [
      """
      graphql do
        authorize? false # To skip authorization for this domain
      end
      """
    ],
    schema: [
      authorize?: [
        type: :boolean,
        doc: "Whether or not to perform authorization for this domain",
        default: true
      ],
      tracer: [
        type: :atom,
        doc:
          "A tracer to use to trace execution in the graphql. Will use `config :ash, :tracer` if it is set."
      ],
      root_level_errors?: [
        type: :boolean,
        default: false,
        doc:
          "By default, mutation errors are shown in their result object's errors key, but this setting places those errors in the top level errors list"
      ],
      error_handler: [
        type: :mfa,
        default: {AshGraphql.DefaultErrorHandler, :handle_error, []},
        doc: """
        Set an MFA to intercept/handle any errors that are generated.
        """
      ],
      show_raised_errors?: [
        type: :boolean,
        default: false,
        doc:
          "For security purposes, if an error is *raised* then Ash simply shows a generic error. If you want to show those errors, set this to true."
      ]
    ]
  }

  @sections [@graphql]

  @moduledoc """
  The entrypoint for adding graphql behavior to an Ash domain
  """

  require Ash.Domain.Info

  use Spark.Dsl.Extension, sections: @sections

  @deprecated "See `AshGraphql.Domain.Info.authorize?/1`"
  defdelegate authorize?(domain), to: AshGraphql.Domain.Info

  @deprecated "See `AshGraphql.Domain.Info.root_level_errors?/1`"
  defdelegate root_level_errors?(domain), to: AshGraphql.Domain.Info

  @deprecated "See `AshGraphql.Domain.Info.show_raised_errors?/1`"
  defdelegate show_raised_errors?(domain), to: AshGraphql.Domain.Info

  @doc false
  def queries(domain, resources, action_middleware, schema, relay_ids?) do
    Enum.flat_map(
      resources,
      &AshGraphql.Resource.queries(domain, &1, action_middleware, schema, relay_ids?)
    )
  end

  @doc false
  def mutations(domain, resources, action_middleware, schema, relay_ids?) do
    resources
    |> Enum.filter(fn resource ->
      AshGraphql.Resource in Spark.extensions(resource)
    end)
    |> Enum.flat_map(
      &AshGraphql.Resource.mutations(domain, &1, action_middleware, schema, relay_ids?)
    )
  end

  @doc false
  def type_definitions(domain, resources, schema, env, first?, define_relay_types?, relay_ids?) do
    resource_types =
      resources
      |> Enum.reject(&Ash.Resource.Info.embedded?/1)
      |> Enum.flat_map(fn resource ->
        if AshGraphql.Resource in Spark.extensions(resource) do
          AshGraphql.Resource.type_definitions(resource, domain, schema, relay_ids?) ++
            AshGraphql.Resource.mutation_types(resource, schema)
        else
          AshGraphql.Resource.no_graphql_types(resource, schema)
        end
      end)

    if first? do
      relay_types =
        if define_relay_types? do
          [
            %Absinthe.Blueprint.Schema.InterfaceTypeDefinition{
              description: "A relay node",
              name: "Node",
              fields: [
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: "A unique identifier",
                  identifier: :id,
                  module: schema,
                  name: "id",
                  __reference__: AshGraphql.Resource.ref(env),
                  type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id}
                }
              ],
              identifier: :node,
              resolve_type: &AshGraphql.Graphql.Resolver.resolve_node_type/2,
              __reference__: AshGraphql.Resource.ref(env),
              module: schema
            },
            %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
              description: "A relay page info",
              name: "PageInfo",
              fields: [
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: "When paginating backwards, are there more items?",
                  identifier: :has_previous_page,
                  module: schema,
                  name: "has_previous_page",
                  __reference__: AshGraphql.Resource.ref(env),
                  type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :boolean}
                },
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: "When paginating forwards, are there more items?",
                  identifier: :has_next_page,
                  module: schema,
                  name: "has_next_page",
                  __reference__: AshGraphql.Resource.ref(env),
                  type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :boolean}
                },
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: "When paginating backwards, the cursor to continue",
                  identifier: :start_cursor,
                  module: schema,
                  name: "start_cursor",
                  __reference__: AshGraphql.Resource.ref(env),
                  type: :string
                },
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: "When paginating forwards, the cursor to continue",
                  identifier: :end_cursor,
                  module: schema,
                  name: "end_cursor",
                  __reference__: AshGraphql.Resource.ref(env),
                  type: :string
                }
                # 'count' field is not compatible with keyset pagination
              ],
              identifier: :page_info,
              module: schema,
              __reference__: AshGraphql.Resource.ref(env)
            }
          ]
        else
          []
        end

      relay_types ++ resource_types
    else
      resource_types
    end
  end

  def global_type_definitions(schema, env) do
    [mutation_error(schema, env), sort_order(schema, env)]
  end

  defp sort_order(schema, env) do
    %Absinthe.Blueprint.Schema.EnumTypeDefinition{
      module: schema,
      name: "SortOrder",
      values: [
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :desc,
          __reference__: AshGraphql.Resource.ref(env),
          name: "DESC",
          value: :desc
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :desc_nils_first,
          __reference__: AshGraphql.Resource.ref(env),
          name: "DESC_NULLS_FIRST",
          value: :des_nils_first
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :desc_nils_last,
          __reference__: AshGraphql.Resource.ref(env),
          name: "DESC_NULLS_LAST",
          value: :desc_nils_last
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :asc,
          __reference__: AshGraphql.Resource.ref(env),
          name: "ASC",
          value: :asc
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :asc_nils_first,
          __reference__: AshGraphql.Resource.ref(env),
          name: "ASC_NULLS_FIRST",
          value: :asc_nils_first
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :asc_nils_last,
          __reference__: AshGraphql.Resource.ref(env),
          name: "ASC_NULLS_LAST",
          value: :asc_nils_last
        }
      ],
      identifier: :sort_order,
      __reference__: AshGraphql.Resource.ref(env)
    }
  end

  defp mutation_error(schema, env) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "An error generated by a failed mutation",
      fields: error_fields(schema, env),
      identifier: :mutation_error,
      module: schema,
      name: "MutationError",
      __reference__: AshGraphql.Resource.ref(env)
    }
  end

  defp error_fields(schema, env) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The human readable error message",
        identifier: :message,
        module: schema,
        __reference__: AshGraphql.Resource.ref(env),
        name: "message",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "A shorter error message, with vars not replaced",
        identifier: :short_message,
        module: schema,
        __reference__: AshGraphql.Resource.ref(env),
        name: "short_message",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Replacements for the short message",
        identifier: :vars,
        module: schema,
        __reference__: AshGraphql.Resource.ref(env),
        name: "vars",
        type: :json
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "An error code for the given error",
        identifier: :code,
        module: schema,
        __reference__: AshGraphql.Resource.ref(env),
        name: "code",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The field or fields that produced the error",
        identifier: :fields,
        module: schema,
        __reference__: AshGraphql.Resource.ref(env),
        name: "fields",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: :string
          }
        }
      }
    ]
  end
end
