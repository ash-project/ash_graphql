# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource do
  alias Ash.Changeset.ManagedRelationshipHelpers
  alias Ash.Query.Aggregate
  alias AshGraphql.Resource
  alias AshGraphql.Resource.{ManagedRelationship, Mutation, Query, Subscription}

  @get %Spark.Dsl.Entity{
    name: :get,
    args: [:name, :action],
    describe: "A query to fetch a record by primary key",
    examples: [
      "get :get_post, :read"
    ],
    schema: Query.get_schema(),
    target: Query,
    auto_set_fields: [
      type: :get
    ]
  }

  @read_one %Spark.Dsl.Entity{
    name: :read_one,
    args: [:name, :action],
    describe: "A query to fetch a record",
    examples: [
      "read_one :current_user, :current_user"
    ],
    schema: Query.read_one_schema(),
    target: Query,
    auto_set_fields: [
      type: :read_one
    ]
  }

  @list %Spark.Dsl.Entity{
    name: :list,
    schema: Query.list_schema(),
    args: [:name, :action],
    describe: "A query to fetch a list of records",
    examples: [
      "list :list_posts, :read",
      "list :list_posts_paginated, :read, relay?: true"
    ],
    target: Query,
    auto_set_fields: [
      type: :list
    ]
  }

  @action_schema [
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
    description: [
      type: :string,
      doc:
        "The description that gets shown in the Graphql schema. If not provided, the action description will be used."
    ],
    hide_inputs: [
      type: {:list, :atom},
      doc: "Inputs to hide in the mutation/query",
      default: []
    ],
    error_location: [
      type: {:one_of, [:in_result, :top_level]},
      doc:
        "If the result should have an `errors` and a `result` key (like create/update/destroy mutations), or if errors should be shown in the top level errors key",
      default: :top_level
    ],
    modify_resolution: [
      type: :mfa,
      doc: """
      An MFA that will be called with the resolution, the query, and the result of the action as the first three arguments. See the [the guide](/documentation/topics/modifying-the-resolution.html) for more.
      """
    ],
    relay_id_translations: [
      type: :keyword_list,
      doc: """
      A keyword list indicating arguments or attributes that have to be translated from global Relay IDs to internal IDs. See the [Relay guide](/documentation/topics/relay.md#translating-relay-global-ids-passed-as-arguments) for more.
      """,
      default: []
    ],
    meta: [
      type: :keyword_list,
      doc: "A keyword list of metadata for the action.",
      default: []
    ]
  ]

  defmodule Action do
    @moduledoc "Represents a configured generic action"
    defstruct [
      :type,
      :name,
      :action,
      :resource,
      :description,
      :relay_id_translations,
      :error_location,
      :modify_resolution,
      :__spark_metadata__,
      args: [],
      hide_inputs: [],
      meta: []
    ]
  end

  @query_action %Spark.Dsl.Entity{
    name: :action,
    schema: @action_schema,
    args: [:name, :action],
    describe: "Runs a generic action",
    examples: [
      "action :check_status, :check_status"
    ],
    target: Action,
    auto_set_fields: [
      type: :action
    ]
  }

  @mutation_action %Spark.Dsl.Entity{
    name: :action,
    schema:
      @action_schema
      |> Spark.Options.merge(
        Mutation.create_schema() |> Keyword.take([:args]),
        "Shared Mutation Options"
      ),
    args: [:name, :action],
    describe: "Runs a generic action",
    examples: [
      "action :check_status, :check_status"
    ],
    target: Action,
    auto_set_fields: [
      type: :action
    ]
  }

  @create %Spark.Dsl.Entity{
    name: :create,
    schema: Mutation.create_schema(),
    args: [:name, :action],
    describe: "A mutation to create a record",
    examples: [
      "create :create_post, :create"
    ],
    target: Mutation,
    auto_set_fields: [
      type: :create
    ]
  }

  @update %Spark.Dsl.Entity{
    name: :update,
    schema: Mutation.update_schema(),
    args: [:name, :action],
    describe: "A mutation to update a record",
    examples: [
      "update :update_post, :update"
    ],
    target: Mutation,
    auto_set_fields: [
      type: :update
    ]
  }

  @destroy %Spark.Dsl.Entity{
    name: :destroy,
    schema: Mutation.destroy_schema(),
    args: [:name, :action],
    describe: "A mutation to destroy a record",
    examples: [
      "destroy :destroy_post, :destroy"
    ],
    target: Mutation,
    auto_set_fields: [
      type: :destroy
    ]
  }

  @queries %Spark.Dsl.Section{
    name: :queries,
    describe: """
    Queries (read actions) to expose for the resource.
    """,
    examples: [
      """
      queries do
        get :get_post, :read
        read_one :current_user, :current_user
        list :list_posts, :read
      end
      """
    ],
    entities: [
      @get,
      @read_one,
      @list,
      @query_action
    ]
  }

  def queries, do: [@get, @read_one, @list, @query_action]

  @managed_relationship %Spark.Dsl.Entity{
    name: :managed_relationship,
    schema: ManagedRelationship.schema(),
    args: [:action, :argument],
    target: ManagedRelationship,
    describe: """
    Configures the behavior of a given managed_relationship for a given action.

    If there are type conflicts (for example, if the input could create or update a record, and the
    create and update actions have an argument of the same name but with a different type),
    a warning is emitted at compile time and the first one is used. If that is insufficient, you will need to do one of the following:

    1.) provide the `:types` option to the `managed_relationship` constructor (see that option for more)
    2.) define a custom type, with a custom input object (see the custom types guide), and use that custom type instead of `:map`
    3.) change your actions to not have overlapping inputs with different types

    Since managed relationships can ultimately call multiple actions, there is the possibility
    of field type conflicts. Use the `types` option to determine the type of fields and remove the conflict warnings.

    For `non_null` use `{:non_null, type}`, and for a list, use `{:array, type}`, for example:

    `{:non_null, {:array, {:non_null, :string}}}` for a non null list of non null strings.

    To *remove* a key from the input object, simply pass `nil` as the type.

    Use `ignore?: true` to skip this type generation.
    """
  }

  @managed_relationships %Spark.Dsl.Section{
    name: :managed_relationships,
    describe: """
    Generates input objects for `manage_relationship` arguments on resource actions.
    """,
    examples: [
      """
      managed_relationships do
        managed_relationship :create_post, :comments
      end
      """
    ],
    schema: [
      auto?: [
        type: :boolean,
        doc:
          "Automatically derive types for all arguments that have a `manage_relationship` call change.",
        default: true
      ]
    ],
    entities: [
      @managed_relationship
    ]
  }

  @mutations %Spark.Dsl.Section{
    name: :mutations,
    describe: """
    Mutations (create/update/destroy actions) to expose for the resource.
    """,
    examples: [
      """
      mutations do
        create :create_post, :create
        update :update_post, :update
        destroy :destroy_post, :destroy
      end
      """
    ],
    entities: [
      @create,
      @update,
      @destroy,
      @mutation_action
    ]
  }

  def mutations, do: [@create, @update, @destroy, @mutation_action]

  @subscribe %Spark.Dsl.Entity{
    name: :subscribe,
    args: [:name],
    describe: "A subscription to listen for changes on the resource",
    examples: [
      """
      subscribe :post_created do
        action_types(:create)
      end
      """
    ],
    schema: Subscription.schema(),
    target: Subscription
  }

  @subscriptions %Spark.Dsl.Section{
    name: :subscriptions,
    schema: [
      pubsub: [
        type: :module,
        doc:
          "The pubsub module to use for the subscription. If not specified, will use the domain's pubsub configuration."
      ]
    ],
    no_depend_modules: [:pubsub],
    describe: """
    Subscriptions (notifications) to expose for the resource.
    """,
    examples: [
      """
      subscriptions do
        subscribe :bucket_created do
          actions :create
          read_action :read
        end
      end
      """
    ],
    entities: [
      @subscribe
    ]
  }

  def subscriptions, do: [@subscribe]

  @graphql %Spark.Dsl.Section{
    name: :graphql,
    imports: [AshGraphql.Resource.Helpers],
    describe: """
    Configuration for a given resource in graphql
    """,
    examples: [
      """
      graphql do
        type :post

        queries do
          get :get_post, :read
          list :list_posts, :read
        end

        mutations do
          create :create_post, :create
          update :update_post, :update
          destroy :destroy_post, :destroy
        end
      end
      """
    ],
    schema: [
      type: [
        type: :atom,
        doc:
          "The type to use for this entity in the graphql schema. If the resource doesn't have a type, it also needs to have `generate_object? false` and can only expose generic action queries."
      ],
      derive_filter?: [
        type: :boolean,
        default: true,
        doc: """
        Set to false to disable the automatic generation of a filter input for read actions.
        """
      ],
      derive_sort?: [
        type: :boolean,
        default: true,
        doc: """
        Set to false to disable the automatic generation of a sort input for read actions.
        """
      ],
      encode_primary_key?: [
        type: :boolean,
        default: true,
        doc:
          "For resources with composite primary keys, or primary keys not called `:id`, this will cause the id to be encoded as a single `id` attribute, both in the representation of the resource and in get requests"
      ],
      relationships: [
        type: {:list, :atom},
        required: false,
        doc:
          "A list of relationships to include on the created type. Defaults to all public relationships where the destination defines a graphql type."
      ],
      paginate_relationship_with: [
        type: :keyword_list,
        default: [],
        doc:
          "A keyword list indicating which kind of pagination should be used for each `has_many` and `many_to_many` relationships, e.g. `related_things: :keyset, other_related_things: :offset`. Valid pagination values are `nil`, `:none`, `:offset`, `:keyset` and `:relay`."
      ],
      field_names: [
        type: :keyword_list,
        doc: "A keyword list of name overrides for attributes."
      ],
      hide_fields: [
        type: {:list, :atom},
        doc: "A list of attributes to hide from the domain"
      ],
      show_fields: [
        type: {:list, :atom},
        doc:
          "A list of attributes to show in the domain. If not specified includes all (excluding `hide_fiels`)."
      ],
      argument_names: [
        type: :keyword_list,
        doc:
          "A nested keyword list of action names, to argument name remappings. i.e `create: [arg_name: :new_name]`"
      ],
      keyset_field: [
        type: :atom,
        doc: """
        If set, the keyset will be displayed on all read actions in this field.  It will be `nil` unless at least one of the read actions on a resource uses keyset pagination or it is the result of a mutation
        """
      ],
      attribute_types: [
        type: :keyword_list,
        doc:
          "A keyword list of type overrides for attributes. The type overrides should refer to types available in the graphql (absinthe) schema. `list_of/1` and `non_null/1` helpers can be used."
      ],
      attribute_input_types: [
        type: :keyword_list,
        doc:
          "A keyword list of input type overrides for attributes. The type overrides should refer to types available in the graphql (absinthe) schema. `list_of/1` and `non_null/1` helpers can be used."
      ],
      argument_input_types: [
        type: :keyword_list,
        doc:
          "A keyword list of actions and their input type overrides for arguments. The type overrides should refer to types available in the graphql (absinthe) schema. `list_of/1` and `non_null/1` helpers can be used."
      ],
      primary_key_delimiter: [
        type: :string,
        default: "~",
        doc:
          "If a composite primary key exists, this can be set to determine delimiter used in the `id` field value."
      ],
      depth_limit: [
        type: :integer,
        doc: """
        A simple way to prevent massive queries.
        """
      ],
      complexity: [
        type: :mod_arg,
        doc: """
        An {module, function} that will be called with the arguments and complexity value of the child fields query. It should return the complexity of this query.
        """
      ],
      generate_object?: [
        type: :boolean,
        doc:
          "Whether or not to create the GraphQL object, this allows you to manually create the GraphQL object.",
        default: true
      ],
      filterable_fields: [
        type: {:list, :atom},
        required: false,
        doc:
          "A list of fields that are allowed to be filtered on. Defaults to all filterable fields for which a GraphQL type can be created."
      ],
      sortable_fields: [
        type: {:list, :atom},
        required: false,
        doc:
          "A list of fields that are allowed to be sorted on. Defaults to all sortable fields for which a GraphQL type can be created."
      ],
      nullable_fields: [
        type: {:wrap_list, :atom},
        doc:
          "Mark fields as nullable even if they are required. This is useful when using field policies. See the authorization guide for more."
      ],
      error_handler: [
        type: :mfa,
        doc: """
        Set an MFA to intercept/handle any errors that are generated.
        """
      ]
    ],
    sections: [
      @queries,
      @mutations,
      @subscriptions,
      @managed_relationships
    ]
  }

  @transformers [
    AshGraphql.Resource.Transformers.RequireKeysetForRelayQueries,
    AshGraphql.Resource.Transformers.ValidateActions,
    AshGraphql.Resource.Transformers.ValidateCompatibleNames,
    AshGraphql.Resource.Transformers.Subscription
  ]

  @verifiers [
    AshGraphql.Resource.Verifiers.VerifyQueryMetadata,
    AshGraphql.Resource.Verifiers.RequirePkeyDelimiter,
    AshGraphql.Resource.Verifiers.VerifyPaginateRelationshipWith,
    AshGraphql.Resource.Verifiers.VerifyArgumentInputTypes
  ]

  @sections [@graphql]

  @moduledoc """
  This Ash resource extension adds configuration for exposing a resource in a graphql.
  """

  use Spark.Dsl.Extension, sections: @sections, transformers: @transformers, verifiers: @verifiers

  @deprecated "See `AshGraphql.Resource.Info.queries/1`"
  defdelegate queries(resource, domain \\ []), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.mutations/1`"
  defdelegate mutations(resource, domain \\ []), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.mutations/1`"
  defdelegate subscriptions(resource, domain \\ []), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.managed_relationships/1`"
  defdelegate managed_relationships(resource), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.type/1`"
  defdelegate type(resource), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.primary_key_delimiter/1`"
  defdelegate primary_key_delimiter(resource), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.generate_object?/1`"
  defdelegate generate_object?(resource), to: AshGraphql.Resource.Info

  def ref(env) do
    %{module: __MODULE__, location: %{file: env.file, line: env.line}}
  end

  # sobelow_skip ["Traversal.FileModule"]
  def codegen(argv) do
    AshGraphql.Codegen.schemas()
    |> Enum.filter(& &1.generate_sdl_file())
    |> Enum.map(fn schema ->
      AshGraphql.Codegen.generate_sdl_file(schema)
    end)
    |> Enum.filter(fn {target, contents} ->
      target_contents =
        if File.exists?(target) do
          File.read!(target)
        else
          ""
        end

      String.trim(target_contents) != String.trim(contents)
    end)
    |> case do
      [] ->
        :ok

      files ->
        cond do
          "--check" in argv ->
            raise Ash.Error.Framework.PendingCodegen, diff: files

          "--dry-run" in argv ->
            Enum.each(files, fn {target, contents} ->
              IO.puts("#{target}\n\n#{contents}")
            end)

          true ->
            Enum.each(files, fn {target, contents} ->
              File.write!(target, contents)
            end)
        end
    end
  end

  if Code.ensure_loaded?(Igniter) do
    # sobelow_skip ["DOS.StringToAtom"]
    def install(igniter, module, Ash.Resource, _path, _argv) do
      type =
        module
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()

      igniter =
        case Ash.Resource.Igniter.domain(igniter, module) do
          {:ok, igniter, domain} ->
            AshGraphql.Domain.install(igniter, domain, Ash.Domain, nil, nil)

          {:error, igniter} ->
            igniter
        end

      igniter
      |> Spark.Igniter.add_extension(
        module,
        Ash.Resource,
        :extensions,
        AshGraphql.Resource
      )
      |> Spark.Igniter.set_option(module, [:graphql, :type], type)
    end
  end

  def encode_id(record, relay_ids?) do
    if relay_ids? do
      encode_relay_id(record)
    else
      encode_primary_key(record)
    end
  end

  def encode_primary_key(%resource{} = record) do
    case Ash.Resource.Info.primary_key(resource) do
      [field] ->
        Map.get(record, field)

      keys ->
        delimiter = primary_key_delimiter(resource)

        [_ | concatenated_keys] =
          keys
          |> Enum.reverse()
          |> Enum.reduce([], fn key, acc -> [delimiter, to_string(Map.get(record, key)), acc] end)

        IO.iodata_to_binary(concatenated_keys)
    end
  end

  def encode_relay_id(%resource{} = record) do
    type = type(resource)
    primary_key = encode_primary_key(record)

    "#{type}:#{primary_key}"
    |> Base.encode64()
  end

  def decode_id(resource, id, relay_ids?) do
    type = type(resource)

    if relay_ids? do
      case decode_relay_id(id) do
        {:ok, %{type: ^type, id: primary_key}} ->
          decode_primary_key(resource, primary_key)

        _ ->
          {:error, Ash.Error.Invalid.InvalidPrimaryKey.exception(resource: resource, value: id)}
      end
    else
      decode_primary_key(resource, id)
    end
  end

  def decode_primary_key(resource, value) do
    case Ash.Resource.Info.primary_key(resource) do
      [field] ->
        {:ok, [{field, value}]}

      fields ->
        delimiter = primary_key_delimiter(resource)
        parts = String.split(value, delimiter)

        if Enum.count(parts) == Enum.count(fields) do
          {:ok, Enum.zip(fields, parts)}
        else
          {:error, "Invalid primary key"}
        end
    end
  end

  def decode_relay_id(id) do
    [type_string, primary_key] =
      id
      |> Base.decode64!()
      |> String.split(":", parts: 2)

    type = String.to_existing_atom(type_string)

    {:ok, %{type: type, id: primary_key}}
  rescue
    _ ->
      {:error, Ash.Error.Invalid.InvalidPrimaryKey.exception(resource: nil, value: id)}
  end

  @doc false
  def queries(
        domain,
        all_domains,
        resource,
        action_middleware,
        schema,
        relay_ids?,
        as_mutations? \\ false
      ) do
    resource
    |> queries(all_domains)
    |> Enum.filter(&(Map.get(&1, :as_mutation?, false) == as_mutations?))
    |> Enum.map(fn
      %{type: :action, name: name, action: action} = query ->
        query_action =
          Ash.Resource.Info.action(resource, action) ||
            raise "No such action #{action} on #{resource}"

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: generic_action_args(query_action, resource, schema),
          identifier: name,
          middleware:
            action_middleware ++
              domain_middleware(domain) ++
              metadata_middleware(query.meta) ++
              id_translation_middleware(query.relay_id_translations, relay_ids?) ++
              [
                {{AshGraphql.Graphql.Resolver, :resolve}, {domain, resource, query, nil}}
              ],
          complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
          module: schema,
          name: to_string(name),
          description: query.description || query_action.description,
          type: generic_action_type(query_action, resource, domain, query),
          __reference__: ref(__ENV__)
        }

      query ->
        query_action =
          Ash.Resource.Info.action(resource, query.action) ||
            raise "No such action #{query.action} on #{resource}"

        type =
          AshGraphql.Resource.Info.type(resource) ||
            raise """
            Resource #{inspect(resource)} is trying to define the query #{inspect(query.name)}
            which requires a GraphQL type to be defined.

            You should define the type of your resource with `type :my_resource_type`.
            """

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments:
            args(
              query.type,
              resource,
              query_action,
              schema,
              query.identity,
              query.hide_inputs,
              query
            ),
          identifier: query.name,
          middleware:
            action_middleware ++
              domain_middleware(domain) ++
              metadata_middleware(query.meta) ++
              id_translation_middleware(query.relay_id_translations, relay_ids?) ++
              [
                {{AshGraphql.Graphql.Resolver, :resolve}, {domain, resource, query, relay_ids?}}
              ],
          complexity: query.complexity || {AshGraphql.Graphql.Resolver, :query_complexity},
          module: schema,
          name: to_string(query.name),
          description: query.description || query_action.description,
          type: query_type(query, resource, query_action, type),
          __reference__: ref(__ENV__)
        }
    end)
  end

  @doc false
  def mutations(domain, all_domains, resource, action_middleware, schema, relay_ids?) do
    resource
    |> mutations(all_domains)
    |> Enum.map(fn mutation ->
      action =
        Ash.Resource.Info.action(resource, mutation.action) ||
          raise "No such action #{mutation.action} for #{inspect(resource)}"

      if mutation.type == :action do
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: mutation_args(mutation, resource, action, schema),
          identifier: mutation.name,
          middleware:
            action_middleware ++
              domain_middleware(domain) ++
              metadata_middleware(mutation.meta) ++
              id_translation_middleware(mutation.relay_id_translations, relay_ids?) ++
              [
                {{AshGraphql.Graphql.Resolver, :resolve},
                 {domain, resource, mutation, mutation.args}}
              ],
          complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
          module: schema,
          name: to_string(mutation.name),
          description: mutation.description || action.description,
          type: generic_action_type(action, resource, domain, mutation),
          __reference__: ref(__ENV__)
        }
      else
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: mutation_args(mutation, resource, action, schema),
          identifier: mutation.name,
          middleware:
            action_middleware ++
              domain_middleware(domain) ++
              metadata_middleware(mutation.meta) ++
              id_translation_middleware(mutation.relay_id_translations, relay_ids?) ++
              [{{AshGraphql.Graphql.Resolver, :mutate}, {domain, resource, mutation, relay_ids?}}],
          module: schema,
          name: to_string(mutation.name),
          description: mutation.description || action.description,
          type: mutation_result_type(mutation.name, domain),
          __reference__: ref(__ENV__)
        }
      end
    end)
    |> Enum.concat(
      queries(domain, all_domains, resource, action_middleware, schema, relay_ids?, true)
    )
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp mutation_result_type(mutation_name, domain) do
    type = String.to_atom("#{mutation_name}_result")
    root_level_errors? = AshGraphql.Domain.Info.root_level_errors?(domain)

    maybe_wrap_non_null(type, not root_level_errors?)
  end

  defp mutation_args(mutation, resource, action, schema) do
    if mutation.type == :action or mutation.type == :create do
      input_args = mutation_input_args(mutation, resource, action, schema)

      input_args
    else
      identity_args = mutation_identity_args(mutation, resource, schema)
      read_args = mutation_read_args(mutation, resource, schema)
      input_args = mutation_input_args(mutation, resource, action, schema)

      identity_args ++ read_args ++ input_args
    end
  end

  defp mutation_identity_args(%{identity: false}, _resource, _schema) do
    []
  end

  defp mutation_identity_args(%{identity: nil}, _resource, schema) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        identifier: :id,
        module: schema,
        name: "id",
        type: maybe_wrap_non_null(:id, true),
        __reference__: ref(__ENV__)
      }
    ]
  end

  defp mutation_identity_args(%{identity: identity}, resource, schema) do
    resource
    |> Ash.Resource.Info.identities()
    |> Enum.find(&(&1.name == identity))
    |> Map.get(:keys)
    |> Enum.map(fn key ->
      attribute = Ash.Resource.Info.attribute(resource, key)

      %Absinthe.Blueprint.Schema.InputValueDefinition{
        identifier: key,
        module: schema,
        name: to_string(key),
        description: attribute.description || "",
        type: %Absinthe.Blueprint.TypeReference.NonNull{
          of_type: field_type(attribute.type, attribute, resource)
        },
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp mutation_read_args(%{read_action: read_action}, resource, schema) do
    read_action =
      cond do
        is_nil(read_action) ->
          Ash.Resource.Info.primary_action!(resource, :read)

        is_atom(read_action) ->
          Ash.Resource.Info.action(resource, read_action)

        true ->
          read_action
      end

    argument_names = AshGraphql.Resource.Info.argument_names(resource)

    read_action.arguments
    |> Enum.filter(& &1.public?)
    |> Enum.map(fn argument ->
      name = argument_names[read_action.name][argument.name] || argument.name

      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(name),
        description: argument.description,
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp mutation_input_args(mutation, resource, action, schema) do
    fields = mutation_fields(resource, schema, action, mutation.type, mutation.hide_inputs)

    {args, fields} =
      Enum.reduce(mutation.args, {[], fields}, fn identifier, {args, fields} ->
        case Enum.split_with(fields, &(&1.identifier == identifier)) do
          {[field], fields} ->
            arg =
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                identifier: field.identifier,
                module: field.module,
                name: field.name,
                description: field.description,
                type: field.type,
                __reference__: ref(__ENV__)
              }

            {args ++ [arg], fields}

          _ ->
            raise "No such input #{identifier} for #{mutation.action} in #{inspect(resource)}"
        end
      end)

    if fields == [] do
      args
    else
      any_non_null_fields? =
        Enum.any?(fields, fn
          %Absinthe.Blueprint.Schema.FieldDefinition{
            type: %Absinthe.Blueprint.TypeReference.NonNull{}
          } ->
            true

          _ ->
            false
        end)

      input_type =
        String.to_atom("#{mutation.name}_input")
        |> maybe_wrap_non_null(any_non_null_fields?)

      input_arg =
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          identifier: :input,
          module: schema,
          name: "input",
          type: input_type,
          __reference__: ref(__ENV__)
        }

      args ++ [input_arg]
    end
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def mutation_types(resource, domain, all_domains, schema) do
    resource_type = AshGraphql.Resource.Info.type(resource)

    resource
    |> mutations(all_domains)
    |> Enum.map(fn mutation ->
      %{
        mutation
        | action:
            Ash.Resource.Info.action(resource, mutation.action) ||
              raise("No such action #{mutation.action} for #{inspect(resource)}")
      }
    end)
    |> Enum.flat_map(fn mutation ->
      description =
        if mutation.type == :destroy do
          "The record that was successfully deleted"
        else
          "The successful result of the mutation"
        end

      fields =
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "Any errors generated, if the mutation failed",
            identifier: :errors,
            module: schema,
            name: "errors",
            type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: %Absinthe.Blueprint.TypeReference.List{
                of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                  of_type: :mutation_error
                }
              }
            },
            __reference__: ref(__ENV__)
          }
        ]

      fields =
        if mutation.type == :action do
          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: description,
              identifier: :result,
              module: schema,
              name: "result",
              type:
                generic_action_type(%{mutation.action | allow_nil?: true}, resource, domain, %{
                  mutation
                  | error_location: :top_level
                }),
              __reference__: ref(__ENV__)
            }
            | fields
          ]
        else
          unless resource_type do
            raise """
            Resource #{inspect(resource)} is trying to define the mutation #{inspect(mutation.name)}
            which requires a GraphQL type to be defined.

            You should define the type of your resource with `type :my_resource_type`.
            """
          end

          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: description,
              identifier: :result,
              module: schema,
              name: "result",
              type: resource_type,
              __reference__: ref(__ENV__)
            }
            | fields
          ]
        end

      metadata_object_type = metadata_field(resource, mutation, schema)

      fields =
        if metadata_object_type do
          fields ++
            [
              %Absinthe.Blueprint.Schema.FieldDefinition{
                description: "Metadata produced by the mutation",
                identifier: :metadata,
                module: schema,
                name: "metadata",
                type: metadata_object_type.identifier,
                __reference__: ref(__ENV__)
              }
            ]
        else
          fields
        end

      result =
        if mutation.action.type == :action && mutation.error_location == :top_level do
          []
        else
          [
            %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
              description: "The result of the #{inspect(mutation.name)} mutation",
              fields: fields,
              identifier: String.to_atom("#{mutation.name}_result"),
              module: schema,
              name: Macro.camelize("#{mutation.name}_result"),
              __reference__: ref(__ENV__)
            }
          ]
        end

      case mutation_fields(
             resource,
             schema,
             mutation.action,
             mutation.type,
             mutation.hide_inputs ++ mutation.args
           ) do
        [] ->
          result ++ List.wrap(metadata_object_type)

        fields ->
          input = %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
            fields: fields,
            identifier: String.to_atom("#{mutation.name}_input"),
            module: schema,
            name: Macro.camelize("#{mutation.name}_input"),
            __reference__: ref(__ENV__)
          }

          [input | result] ++ List.wrap(metadata_object_type)
      end
    end)
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def query_types(resource, domain, all_domains, schema) do
    resource
    |> queries(all_domains)
    |> Enum.filter(&(&1.type == :action && &1.error_location == :in_result))
    |> Enum.map(fn mutation ->
      mutation =
        %{
          mutation
          | action:
              Ash.Resource.Info.action(resource, mutation.action) ||
                raise("No such action #{mutation.action} for #{inspect(resource)}")
        }

      fields =
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The successful result of the query",
            identifier: :result,
            module: schema,
            name: "result",
            type:
              generic_action_type(%{mutation.action | allow_nil?: true}, resource, domain, %{
                mutation
                | error_location: :top_level
              }),
            __reference__: ref(__ENV__)
          },
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "Any errors generated, if the mutation failed",
            identifier: :errors,
            module: schema,
            name: "errors",
            type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: %Absinthe.Blueprint.TypeReference.List{
                of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                  of_type: :mutation_error
                }
              }
            },
            __reference__: ref(__ENV__)
          }
        ]

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "The result of the #{inspect(mutation.name)} query",
        fields: fields,
        identifier: String.to_atom("#{mutation.name}_result"),
        module: schema,
        name: Macro.camelize("#{mutation.name}_result"),
        __reference__: ref(__ENV__)
      }
    end)
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]

  def subscription_types(resource, all_domains, schema) do
    resource
    |> subscriptions(all_domains)
    |> Enum.map(fn %Subscription{name: name, actions: actions, action_types: action_types} ->
      resource_type = AshGraphql.Resource.Info.type(resource)

      action_types =
        Ash.Resource.Info.actions(resource)
        |> Stream.filter(&(&1.name in List.wrap(actions)))
        |> Stream.map(& &1.type)
        |> Stream.concat(List.wrap(action_types))
        |> Enum.uniq()

      result_type_name =
        name
        |> to_string()
        |> then(&(&1 <> "_result"))

      result_type =
        result_type_name
        |> String.to_atom()

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        module: schema,
        identifier: result_type,
        name: result_type_name,
        fields:
          [
            :create in action_types &&
              %Absinthe.Blueprint.Schema.FieldDefinition{
                __reference__: ref(__ENV__),
                identifier: :created,
                module: schema,
                name: "created",
                type: resource_type
              },
            :update in action_types &&
              %Absinthe.Blueprint.Schema.FieldDefinition{
                __reference__: ref(__ENV__),
                identifier: :updated,
                module: schema,
                name: "updated",
                type: resource_type
              },
            :destroy in action_types &&
              %Absinthe.Blueprint.Schema.FieldDefinition{
                __reference__: ref(__ENV__),
                identifier: :destroyed,
                module: schema,
                name: "destroyed",
                type: :id
              }
          ]
          |> Enum.filter(&(&1 != false)),
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp id_translation_middleware(relay_id_translations, true) do
    [{{AshGraphql.Graphql.IdTranslator, :translate_relay_ids}, relay_id_translations}]
  end

  defp id_translation_middleware(_relay_id_translations, _relay_ids?) do
    []
  end

  defp domain_middleware(domain) do
    [{{AshGraphql.Graphql.DomainMiddleware, :set_domain}, domain}]
  end

  defp metadata_middleware(metadata) do
    [{{AshGraphql.Graphql.MetadataMiddleware, :set_metadata}, metadata}]
  end

  # sobelow_skip ["DOS.StringToAtom"]

  defp metadata_field(resource, mutation, schema) do
    metadata_fields =
      Map.get(mutation.action, :metadata, [])
      |> Enum.map(fn metadata ->
        field_type =
          metadata.type
          |> field_type(metadata, resource)
          |> maybe_wrap_non_null(not metadata.allow_nil?)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: metadata.description,
          identifier: metadata.name,
          module: schema,
          name: to_string(metadata.name),
          type: field_type,
          __reference__: ref(__ENV__)
        }
      end)

    if !Enum.empty?(metadata_fields) do
      name = "#{mutation.name}_metadata"

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        fields: metadata_fields,
        identifier: String.to_atom(name),
        module: schema,
        name: Macro.camelize(name),
        __reference__: ref(__ENV__)
      }
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @doc false

  def subscriptions(domain, all_domains, resource, action_middleware, schema, relay_ids?) do
    resource
    |> subscriptions(all_domains)
    |> Enum.map(fn %Subscription{name: name, hide_inputs: hide_inputs} = subscription ->
      result_type = name |> to_string() |> then(&(&1 <> "_result")) |> String.to_atom()

      action =
        Ash.Resource.Info.action(resource, subscription.read_action) ||
          Ash.Resource.Info.primary_action(resource, :read)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        arguments: args(:subscription, resource, action, schema, nil, hide_inputs),
        identifier: name,
        name: to_string(name),
        config:
          AshGraphql.Subscription.Config.create_config(
            subscription,
            domain,
            resource
          ),
        module: schema,
        middleware:
          action_middleware ++
            domain_middleware(domain) ++
            metadata_middleware(subscription.meta) ++
            id_translation_middleware(subscription.relay_id_translations, relay_ids?) ++
            [
              {{AshGraphql.Graphql.Resolver, :resolve},
               {domain, resource, subscription, relay_ids?}}
            ],
        type: result_type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def embedded_type_input(source_resource, attribute, resource, schema) do
    attribute = %{
      attribute
      | constraints: Ash.Type.NewType.constraints(resource, attribute.constraints)
    }

    resource = Ash.Type.NewType.subtype_of(resource)

    create_action =
      case attribute.constraints[:create_action] do
        nil ->
          Ash.Resource.Info.primary_action!(resource, :create)

        name ->
          Ash.Resource.Info.action(resource, name)
      end

    update_action =
      case attribute.constraints[:update_action] do
        nil ->
          Ash.Resource.Info.primary_action!(resource, :update)

        name ->
          Ash.Resource.Info.action(resource, name)
      end

    fields =
      mutation_fields(resource, schema, create_action, :create) ++
        mutation_fields(resource, schema, update_action, :update)

    fields =
      fields
      |> Enum.group_by(& &1.identifier)
      # We only want one field per id. Right now we just take the first one
      # If there are overlaps, and the field isn't `NonNull` in *all* cases, then
      # we pick one and mark it explicitly as nullable (we unwrap the `NonNull`)
      |> Enum.map(fn {_id, fields} ->
        if Enum.all?(
             fields,
             &match?(%Absinthe.Blueprint.TypeReference.NonNull{}, &1.type)
           ) do
          Enum.at(fields, 0)
        else
          fields
          |> Enum.at(0)
          |> case do
            %{type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: type}} = field ->
              %{field | type: type}

            field ->
              field
          end
        end
      end)

    unless Enum.empty?(fields) do
      name = "#{AshGraphql.Resource.Info.type(source_resource)}_#{attribute.name}_input"

      %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
        fields: fields,
        identifier: String.to_atom(name),
        module: schema,
        name: Macro.camelize(name),
        __reference__: ref(__ENV__)
      }
    end
  end

  defp mutation_fields(resource, schema, action, type, hide_inputs \\ []) do
    field_names = AshGraphql.Resource.Info.field_names(resource)
    argument_names = AshGraphql.Resource.Info.argument_names(resource)[action.name]
    argument_input_types = AshGraphql.Resource.Info.argument_input_types(resource)[action.name]

    attribute_fields =
      cond do
        action.type == :action ->
          []

        action.type == :destroy && !action.soft? ->
          []

        true ->
          resource
          |> Ash.Resource.Info.attributes()
          |> Enum.filter(fn attribute ->
            AshGraphql.Resource.Info.show_field?(resource, attribute.name) &&
              attribute.name in action.accept && attribute.writable? &&
              attribute.name not in hide_inputs
          end)
          |> Enum.map(fn attribute ->
            allow_nil? =
              attribute.allow_nil? || attribute.default != nil || type == :update ||
                attribute.generated? ||
                (type == :create && attribute.name in action.allow_nil_input)

            explicitly_required = attribute.name in action.require_attributes

            field_type =
              attribute.type
              |> field_type(attribute, resource, true)
              |> maybe_wrap_non_null(explicitly_required || not allow_nil?)

            name = field_names[attribute.name] || attribute.name

            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: attribute.name,
              module: schema,
              name: to_string(name),
              description: attribute.description,
              type: field_type,
              __reference__: ref(__ENV__)
            }
          end)
      end

    argument_fields =
      action.arguments
      |> Enum.filter(&(&1.public? && &1.name not in hide_inputs))
      |> Enum.map(fn argument ->
        argument_type =
          case find_manage_change(argument, action, resource) do
            nil ->
              case argument_input_types[argument.name] do
                nil ->
                  argument.type
                  |> field_type(argument, resource, true)
                  |> maybe_wrap_non_null(argument_required?(argument))

                override ->
                  unwrap_literal_type(override)
              end

            _manage_opts ->
              managed = AshGraphql.Resource.Info.managed_relationship(resource, action, argument)

              prev_requirements = Process.get(:managed_relationship_requirements, [])
              next_requirements = [{resource, managed, action, argument} | prev_requirements]
              Process.put(:managed_relationship_requirements, next_requirements)

              type = managed.type_name || default_managed_type_name(resource, action, argument)

              wrap_arrays(argument.type, type, argument.constraints)
          end

        name = argument_names[argument.name] || argument.name

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: argument.name,
          module: schema,
          name: to_string(name),
          description: argument.description,
          type: argument_type,
          __reference__: ref(__ENV__)
        }
      end)

    attribute_fields ++ argument_fields
  end

  defp wrap_arrays({:array, arg_type}, type, constraints) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type:
        maybe_wrap_non_null(
          wrap_arrays(arg_type, type, constraints[:items] || []),
          !constraints[:nil_items?] || embedded?(type)
        )
    }
  end

  defp wrap_arrays(_, type, _), do: type

  # sobelow_skip ["DOS.StringToAtom"]
  defp default_managed_type_name(resource, action, argument) do
    String.to_atom(
      to_string(AshGraphql.Resource.Info.type(resource)) <>
        "_" <>
        to_string(action.name) <>
        "_" <> to_string(argument.name) <> "_input"
    )
  end

  @doc false
  def find_manage_change(argument, action, resource) do
    if AshGraphql.Resource.Info.managed_relationship(resource, action, argument) do
      Enum.find_value(action.changes, fn
        %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
          opts[:argument] == argument.name && opts

        _ ->
          nil
      end)
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp query_type(%{type: :list, relay?: relay?} = query, _resource, action, type) do
    type = query.type_name || type

    if relay? do
      String.to_atom("#{type}_connection")
    else
      case query_pagination_strategy(query, action) do
        :keyset ->
          String.to_atom("keyset_page_of_#{type}")

        :offset ->
          String.to_atom("page_of_#{type}")

        nil ->
          %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: %Absinthe.Blueprint.TypeReference.List{
              of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: type
              }
            }
          }
      end
    end
  end

  defp query_type(query, _resource, _action, type) do
    type = query.type_name || type

    maybe_wrap_non_null(type, not query.allow_nil?)
  end

  @doc false
  def query_pagination_strategy(nil, _) do
    nil
  end

  def query_pagination_strategy(%{paginate_with: strategy}, action) do
    pagination_strategy(strategy, action)
  end

  @doc false
  def relationship_pagination_strategy(resource, relationship_name, action) do
    resource
    |> AshGraphql.Resource.Info.paginate_relationship_with()
    |> Keyword.get(relationship_name)
    |> pagination_strategy(action, true)
  end

  defp pagination_strategy(strategy, action, allow_relay? \\ false)

  defp pagination_strategy(:none, _action, _allow_relay?) do
    :none
  end

  defp pagination_strategy(_strategy, %{pagination: pagination}, _allow_relay?)
       when pagination in [nil, false] do
    nil
  end

  defp pagination_strategy(strategy, action, allow_relay?) do
    strategies =
      if Application.get_env(:ash_graphql, :required_pagination_extends_to_relationships, false) do
        if action.pagination.required? do
          []
        else
          [nil]
        end
      else
        [nil]
      end

    strategies =
      if action.pagination.keyset? do
        [:keyset | strategies]
      else
        strategies
      end

    strategies =
      if action.pagination.offset? do
        [:offset | strategies]
      else
        strategies
      end

    strategies =
      if allow_relay? and action.pagination.keyset? do
        [:relay | strategies]
      else
        strategies
      end

    if strategy in strategies do
      strategy
    else
      Enum.at(strategies, 0)
    end
  end

  defp maybe_wrap_non_null({:non_null, type}, true) do
    %Absinthe.Blueprint.TypeReference.NonNull{
      of_type: type
    }
  end

  defp maybe_wrap_non_null(type, true) do
    %Absinthe.Blueprint.TypeReference.NonNull{
      of_type: type
    }
  end

  defp maybe_wrap_non_null(type, _), do: type

  defp get_fields(resource) do
    if AshGraphql.Resource.Info.encode_primary_key?(resource) do
      [
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "id",
          identifier: :id,
          type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
          description: "The id of the record",
          __reference__: ref(__ENV__)
        }
      ]
    else
      resource
      |> Ash.Resource.Info.primary_key()
      |> Enum.map(fn key ->
        attribute = Ash.Resource.Info.attribute(resource, key)

        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: to_string(key),
          identifier: key,
          type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: field_type(attribute.type, attribute, resource, true)
          },
          description: attribute.description || "",
          __reference__: ref(__ENV__)
        }
      end)
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp generic_action_type(_action, _resource, domain, %{name: name, error_location: :in_result}) do
    type = String.to_atom("#{name}_result")
    root_level_errors? = AshGraphql.Domain.Info.root_level_errors?(domain)

    maybe_wrap_non_null(type, not root_level_errors?)
  end

  defp generic_action_type(action, resource, _domain, _gql_action) do
    fake_attribute = %{
      type: action.returns || Ash.Type.Boolean,
      constraints: action.constraints,
      allow_nil?: Map.get(action, :allow_nil?, false),
      name: action.name
    }

    fake_attribute.type
    |> field_type(fake_attribute, resource, false)
    |> maybe_wrap_non_null(argument_required?(fake_attribute))
  end

  defp generic_action_args(action, resource, schema) do
    argument_names = AshGraphql.Resource.Info.argument_names(resource)

    action.arguments
    |> Enum.filter(& &1.public?)
    |> Enum.map(fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      name = argument_names[action.name][argument.name] || argument.name

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(name),
        description: argument.description,
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp args(
         action_type,
         resource,
         action,
         schema,
         identity \\ nil,
         hide_inputs \\ [],
         query \\ nil
       )

  defp args(:get, resource, action, schema, nil, hide_inputs, _query) do
    get_fields(resource) ++
      read_args(resource, action, schema, hide_inputs)
  end

  defp args(:get, resource, action, schema, identity, hide_inputs, _query) do
    if identity do
      resource
      |> Ash.Resource.Info.identities()
      |> Enum.find(&(&1.name == identity))
      |> Map.get(:keys)
      |> Enum.map(fn key ->
        attribute = Ash.Resource.Info.attribute(resource, key)

        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: to_string(key),
          identifier: key,
          type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: field_type(attribute.type, attribute, resource, true)
          },
          description: attribute.description || "",
          __reference__: ref(__ENV__)
        }
      end)
    else
      []
    end
    |> Enum.concat(read_args(resource, action, schema, hide_inputs))
  end

  defp args(:read_one, resource, action, schema, _, hide_inputs, _query) do
    args =
      if AshGraphql.Resource.Info.derive_filter?(resource) do
        case resource_filter_fields(resource, schema) do
          [] ->
            []

          _ ->
            [
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                name: "filter",
                identifier: :filter,
                type: resource_filter_type(resource),
                description: "A filter to limit the results",
                __reference__: ref(__ENV__)
              }
            ]
        end
      else
        []
      end

    args ++ read_args(resource, action, schema, hide_inputs)
  end

  defp args(:list, resource, action, schema, _, hide_inputs, query) do
    args =
      if AshGraphql.Resource.Info.derive_filter?(resource) do
        case resource_filter_fields(resource, schema) do
          [] ->
            []

          _ ->
            [
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                name: "filter",
                identifier: :filter,
                type: resource_filter_type(resource),
                description: "A filter to limit the results",
                __reference__: ref(__ENV__)
              }
            ]
        end
      else
        []
      end

    args =
      if AshGraphql.Resource.Info.derive_sort?(resource) do
        case sort_values(resource) do
          [] ->
            args

          _ ->
            [
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                name: "sort",
                identifier: :sort,
                type: %Absinthe.Blueprint.TypeReference.List{
                  of_type: resource_sort_type(resource)
                },
                description: "How to sort the records in the response",
                __reference__: ref(__ENV__)
              }
              | args
            ]
        end
      else
        args
      end

    args ++ pagination_args(query, action) ++ read_args(resource, action, schema, hide_inputs)
  end

  defp args(:one_related, resource, action, schema, _identity, hide_inputs, _) do
    read_args(resource, action, schema, hide_inputs)
  end

  defp args(:subscription, resource, action, schema, _identity, hide_inputs, _query) do
    args =
      if AshGraphql.Resource.Info.derive_filter?(resource) do
        case resource_filter_fields(resource, schema) do
          [] ->
            []

          _ ->
            [
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                name: "filter",
                identifier: :filter,
                type: resource_filter_type(resource),
                description: "A filter to limit the results",
                __reference__: ref(__ENV__)
              }
            ]
        end
      else
        []
      end

    args ++ read_args(resource, action, schema, hide_inputs)
  end

  defp related_list_args(resource, related_resource, relationship_name, action, schema) do
    args(:list, related_resource, action, schema) ++
      relationship_pagination_args(resource, relationship_name, action)
  end

  defp read_args(resource, action, schema, hide_inputs) do
    argument_names = AshGraphql.Resource.Info.argument_names(resource)

    action.arguments
    |> Enum.filter(&(&1.public? && &1.name not in hide_inputs))
    |> Enum.map(fn argument ->
      name = argument_names[action.name][argument.name] || argument.name

      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(name),
        description: argument.description,
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp relationship_pagination_args(resource, relationship_name, action) do
    case relationship_pagination_strategy(resource, relationship_name, action) do
      nil ->
        default_relationship_pagination_args()

      :none ->
        []

      :keyset ->
        keyset_pagination_args(action)

      :relay ->
        # Relay has the same args as keyset
        keyset_pagination_args(action)

      :offset ->
        offset_pagination_args(action)
    end
  end

  defp default_relationship_pagination_args do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "limit",
        identifier: :limit,
        type: :integer,
        description: "The number of records to return.",
        __reference__: ref(__ENV__)
      },
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "offset",
        identifier: :offset,
        type: :integer,
        description: "The number of records to skip.",
        __reference__: ref(__ENV__)
      }
    ]
  end

  defp pagination_args(query, action) do
    case query_pagination_strategy(query, action) do
      nil ->
        []

      :keyset ->
        keyset_pagination_args(action)

      :offset ->
        offset_pagination_args(action)
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp resource_sort_type(resource) do
    String.to_atom(to_string(AshGraphql.Resource.Info.type(resource)) <> "_sort_input")
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp resource_filter_type(resource) do
    String.to_atom(to_string(AshGraphql.Resource.Info.type(resource)) <> "_filter_input")
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp attribute_filter_field_type(resource, attribute) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    String.to_atom(
      to_string(AshGraphql.Resource.Info.type(resource)) <>
        "_filter_" <> to_string(field_names[attribute.name] || attribute.name)
    )
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp calculation_filter_field_type(resource, calculation) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    String.to_atom(
      to_string(AshGraphql.Resource.Info.type(resource)) <>
        "_filter_" <> to_string(field_names[calculation.name] || calculation.name)
    )
  end

  defp keyset_pagination_args(action) do
    if action.pagination.keyset? do
      max_message =
        if action.pagination.max_page_size do
          " Maximum #{action.pagination.max_page_size}"
        else
          ""
        end

      [
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "first",
          identifier: :first,
          type: :integer,
          description: "The number of records to return from the beginning." <> max_message,
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "before",
          identifier: :before,
          type: :string,
          description: "Show records before the specified keyset.",
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "after",
          identifier: :after,
          type: :string,
          description: "Show records after the specified keyset.",
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "last",
          identifier: :last,
          type: :integer,
          description: "The number of records to return to the end." <> max_message,
          __reference__: ref(__ENV__)
        }
      ]
    else
      []
    end
  end

  defp offset_pagination_args(action) do
    if action.pagination.offset? do
      max_message =
        if action.pagination.max_page_size do
          " Maximum #{action.pagination.max_page_size}"
        else
          ""
        end

      limit_type =
        maybe_wrap_non_null(
          :integer,
          action.pagination.required? && is_nil(action.pagination.default_limit)
        )

      [
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "limit",
          identifier: :limit,
          type: limit_type,
          default_value: action.pagination.default_limit,
          description: "The number of records to return." <> max_message,
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "offset",
          identifier: :offset,
          type: :integer,
          description: "The number of records to skip.",
          __reference__: ref(__ENV__)
        }
      ]
    else
      []
    end
  end

  @doc false
  def type_definitions(resource, domain, all_domains, schema, relay_ids?) do
    List.wrap(type_definition(resource, domain, all_domains, schema, relay_ids?)) ++
      List.wrap(query_type_definitions(resource, domain, all_domains, schema, relay_ids?)) ++
      List.wrap(sort_input(resource, schema)) ++
      List.wrap(filter_input(resource, schema)) ++
      filter_field_types(resource, schema) ++
      List.wrap(page_type_definitions(resource, schema)) ++
      enum_definitions(resource, schema, __ENV__)
  end

  def no_graphql_types(resource, schema) do
    enum_definitions(resource, schema, __ENV__)
  end

  def managed_relationship_definitions(used, schema) do
    Enum.map(used, fn {resource, managed_relationship, action, argument} ->
      opts =
        find_manage_change(argument, action, resource) ||
          raise """
          There is no corresponding `change manage_change(...)` for the given argument and action
          combination.
          """

      managed_relationship_input(
        resource,
        action,
        opts,
        argument,
        managed_relationship,
        schema
      )
    end)
  end

  defp managed_relationship_input(resource, action, opts, argument, managed_relationship, schema) do
    relationship =
      Ash.Resource.Info.relationship(resource, opts[:relationship]) ||
        raise """
        No relationship found when building managed relationship input: #{opts[:relationship]}
        """

    manage_opts_schema =
      if opts[:opts][:type] do
        defaults = Ash.Changeset.manage_relationship_opts(opts[:opts][:type])

        Enum.reduce(defaults, Ash.Changeset.manage_relationship_schema(), fn {key, value},
                                                                             manage_opts ->
          Spark.Options.Helpers.set_default!(manage_opts, key, value)
        end)
      else
        Ash.Changeset.manage_relationship_schema()
      end

    manage_opts = Spark.Options.validate!(opts[:opts], manage_opts_schema)

    fields =
      manage_fields(resource, manage_opts, managed_relationship, relationship, schema)

    type = managed_relationship.type_name || default_managed_type_name(resource, action, argument)

    fields =
      check_for_conflicts!(fields, managed_relationship, resource)

    if Enum.empty?(fields) do
      raise """
      Input object for managed relationship #{relationship.name} on #{inspect(relationship.source)}#{action.name} would have no fields.

      This typically means that you are missing the `lookup_with_primary_key?` option or the `lookup_identities` option on the configured
      managed_relationship DSL. For example, calls to `manage_relationship` that only look things up and accept no modifications
      (like `type: :accept`), they will have no fields because we don't assume the primary key or specific identities should be included in the
      input object.
      """
    end

    %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
      identifier: type,
      fields: fields,
      module: schema,
      name: type |> to_string() |> Macro.camelize(),
      __reference__: ref(__ENV__)
    }
  end

  @doc false
  def manage_fields(_resource, manage_opts, managed_relationship, relationship, schema) do
    [
      on_match_fields(manage_opts, relationship, schema),
      on_no_match_fields(manage_opts, relationship, schema),
      on_lookup_fields(manage_opts, relationship, schema),
      manage_pkey_fields(manage_opts, managed_relationship, relationship, schema)
    ]
    |> Enum.reject(&(&1 == :none))
    |> case do
      [] ->
        []

      [one] ->
        one

      field_sets ->
        Enum.reduce(field_sets, [], fn field_set, fields ->
          new_fields =
            Enum.reduce(field_set, [], fn {resource, action, field}, fields ->
              if required?(field) do
                maybe_unrequire(field_sets, resource, action, field, fields)
              else
                [{resource, action, field} | fields]
              end
            end)
            |> Enum.sort_by(fn {_resource, _action, field} -> field.name end)

          fields ++ new_fields
        end)
    end
  end

  defp maybe_unrequire(field_sets, resource, action, field, fields) do
    if Enum.all?(field_sets, fn field_set ->
         Enum.any?(field_set, fn {_, _, other_field} ->
           other_field.identifier == field.identifier && required?(other_field)
         end)
       end) do
      [{resource, action, field} | fields]
    else
      [{resource, action, %{field | type: field.type.of_type}} | fields]
    end
  end

  defp required?(%{type: %Absinthe.Blueprint.TypeReference.NonNull{}}), do: true
  defp required?(_), do: false

  defp check_for_conflicts!(fields, managed_relationship, resource) do
    {ok, errors} =
      fields
      |> Enum.map(fn {resource, action, field} ->
        %{field: field, source: %{resource: resource, action: action}}
      end)
      |> Enum.group_by(& &1.field.identifier)
      |> Enum.map(fn {identifier, data} ->
        case Keyword.fetch(managed_relationship.types || [], identifier) do
          {:ok, nil} ->
            nil

          {:ok, type} ->
            type = unwrap_literal_type(type)
            {:ok, %{Enum.at(data, 0).field | type: type}}

          :error ->
            get_conflicts(data)
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.split_with(&match?({:ok, _}, &1))

    unless Enum.empty?(errors) do
      raise_conflicts!(Enum.map(errors, &elem(&1, 1)), managed_relationship, resource)
    end

    Enum.map(ok, &elem(&1, 1))
  end

  defp raise_conflicts!(conflicts, managed_relationship, resource) do
    action_name =
      case managed_relationship.action do
        name when is_atom(name) -> name
        %{name: name} -> name
      end

    raise """
    #{inspect(resource)}: #{action_name}.#{managed_relationship.argument}

    Error while deriving managed relationship input object type: type conflict.

    Because multiple actions could be called, and those actions may have different
    derived types, you will need to override the graphql schema to specify the type
    for the following fields. This can be done by specifying the `types` option on your
    `managed_relationship` inside of the `managed_relationships` in your resource's
    `graphql` configuration.

    #{Enum.map_join(conflicts, "\n\n", &conflict_message(&1, managed_relationship))}
    """
  end

  defp conflict_message(
         {_reducing_type, _type, [%{field: %{name: name}} | _] = fields},
         managed_relationship
       ) do
    formatted_types =
      fields
      |> Enum.map(fn
        %{source: %{action: :__primary_key}} = field ->
          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}'s lookup by primary key"

        %{source: %{action: {:identity, identity}}} = field ->
          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}'s identity: #{identity}"

        field ->
          action =
            case field.source.action do
              %{name: name} -> name
              name -> name
            end
            |> then(fn action ->
              try do
                to_string(action)
              rescue
                _ ->
                  inspect(action)
              end
            end)

          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}.#{action}"
      end)
      |> Enum.uniq()

    """
    Possible types for #{managed_relationship.action}.#{managed_relationship.argument}.#{name}:

    #{Enum.map(formatted_types, &"  * #{&1}\n")}
    """
  end

  defp unwrap_literal_type({:non_null, {:non_null, type}}) do
    unwrap_literal_type({:non_null, type})
  end

  defp unwrap_literal_type({:array, {:array, type}}) do
    unwrap_literal_type({:array, type})
  end

  defp unwrap_literal_type({:non_null, type}) do
    %Absinthe.Blueprint.TypeReference.NonNull{of_type: unwrap_literal_type(type)}
  end

  defp unwrap_literal_type({:array, type}) do
    %Absinthe.Blueprint.TypeReference.List{of_type: unwrap_literal_type(type)}
  end

  defp unwrap_literal_type(type) do
    type
  end

  defp format_type(%Absinthe.Blueprint.TypeReference.NonNull{of_type: type}) do
    {:non_null, format_type(type)}
  end

  defp format_type(%Absinthe.Blueprint.TypeReference.List{of_type: type}) do
    {:array, format_type(type)}
  end

  defp format_type(type) do
    type
  end

  defp get_conflicts([field]) do
    {:ok, field.field}
  end

  defp get_conflicts([field | _] = fields) do
    case reduce_types(fields) do
      {:ok, res} ->
        {:ok, %{field.field | type: res}}

      {:error, {reducing_type, type}} ->
        {:error, {reducing_type, type, fields}}
    end
  end

  defp reduce_types(fields) do
    Enum.reduce_while(fields, {:ok, nil}, fn field, {:ok, type} ->
      if type do
        case match_types(type, field.field.type) do
          {:ok, value} ->
            {:cont, {:ok, value}}

          :error ->
            {:halt, {:error, {type, field.field.type}}}
        end
      else
        {:cont, {:ok, field.field.type}}
      end
    end)
  end

  defp match_types(
         %Absinthe.Blueprint.TypeReference.NonNull{
           of_type: type
         },
         type
       ) do
    {:ok, type}
  end

  defp match_types(
         type,
         %Absinthe.Blueprint.TypeReference.NonNull{
           of_type: type
         }
       ) do
    {:ok, type}
  end

  defp match_types(
         type,
         type
       ) do
    {:ok, type}
  end

  defp match_types(_, _) do
    :error
  end

  defp on_lookup_fields(opts, relationship, schema) do
    case ManagedRelationshipHelpers.on_lookup_update_action(opts, relationship) do
      {:destination, nil} ->
        :none

      {:destination, action} ->
        action = Ash.Resource.Info.action(relationship.destination, action)

        relationship.destination
        |> mutation_fields(schema, action, action.type)
        |> Enum.map(fn field ->
          {relationship.destination, action.name, field}
        end)
        |> Enum.reject(fn {_, _, field} ->
          field.identifier == relationship.destination_attribute
        end)

      {:join, nil, _} ->
        :none

      {:join, action, fields} ->
        action = Ash.Resource.Info.action(relationship.through, action)

        if fields == :all do
          mutation_fields(relationship.through, schema, action, action.type)
        else
          relationship.through
          |> mutation_fields(schema, action, action.type)
          |> Enum.filter(&(&1.identifier in fields))
        end
        |> Enum.map(fn field ->
          {relationship.through, action.name, field}
        end)
        |> Enum.reject(fn {_, _, field} ->
          field.identifier in [
            relationship.destination_attribute_on_join_resource,
            relationship.source_attribute_on_join_resource
          ]
        end)

      nil ->
        :none
    end
  end

  defp on_match_fields(opts, relationship, schema) do
    opts
    |> ManagedRelationshipHelpers.on_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.reject(fn
      {:join, nil, _} ->
        true

      {:destination, nil} ->
        true

      _ ->
        false
    end)
    |> case do
      [] ->
        :none

      actions ->
        Enum.flat_map(actions, fn
          {:destination, action_name} ->
            action = Ash.Resource.Info.action(relationship.destination, action_name)

            relationship.destination
            |> mutation_fields(schema, action, action.type)
            |> Enum.map(fn field ->
              {relationship.destination, action.name, field}
            end)
            |> Enum.reject(fn {_, _, field} ->
              field.identifier == relationship.destination_attribute
            end)

          {:join, action_name, fields} ->
            action = Ash.Resource.Info.action(relationship.through, action_name)

            if fields == :all do
              mutation_fields(relationship.through, schema, action, action.type)
            else
              relationship.through
              |> mutation_fields(schema, action, action.type)
              |> Enum.filter(&(&1.identifier in fields))
            end
            |> Enum.map(fn field ->
              {relationship.through, action.name, field}
            end)
            |> Enum.reject(fn {_, _, field} ->
              field.identifier in [
                relationship.destination_attribute_on_join_resource,
                relationship.source_attribute_on_join_resource
              ]
            end)
        end)
    end
  end

  defp on_no_match_fields(opts, relationship, schema) do
    opts
    |> ManagedRelationshipHelpers.on_no_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.reject(fn
      {:join, nil, _} ->
        true

      {:destination, nil} ->
        true

      _ ->
        false
    end)
    |> case do
      [] ->
        :none

      actions ->
        Enum.flat_map(actions, fn
          {:destination, action_name} ->
            action = Ash.Resource.Info.action(relationship.destination, action_name)

            relationship.destination
            |> mutation_fields(schema, action, action.type)
            |> Enum.map(fn field ->
              {relationship.destination, action.name, field}
            end)
            |> Enum.reject(fn {_, _, field} ->
              field.identifier == relationship.destination_attribute
            end)

          {:join, action_name, fields} ->
            action = Ash.Resource.Info.action(relationship.through, action_name)

            if fields == :all do
              mutation_fields(relationship.through, schema, action, action.type)
            else
              relationship.through
              |> mutation_fields(schema, action, action.type)
              |> Enum.filter(&(&1.identifier in fields))
            end
            |> Enum.map(fn field ->
              {relationship.through, action.name, field}
            end)
            |> Enum.reject(fn {_, _, field} ->
              field.identifier in [
                relationship.destination_attribute_on_join_resource,
                relationship.source_attribute_on_join_resource
              ]
            end)
        end)
    end
  end

  defp manage_pkey_fields(opts, managed_relationship, relationship, schema) do
    resource = relationship.destination
    could_lookup? = ManagedRelationshipHelpers.could_lookup?(opts)
    could_match? = ManagedRelationshipHelpers.could_update?(opts)

    if could_lookup? || could_match? do
      pkey_fields =
        if managed_relationship.lookup_with_primary_key? || could_match? do
          resource
          |> pkey_fields(schema, false)
          |> Enum.map(fn field ->
            {resource, :__primary_key, field}
          end)
        else
          []
        end

      resource
      |> Ash.Resource.Info.identities()
      |> then(fn identities ->
        if could_lookup? do
          identities
        else
          []
        end
      end)
      |> Enum.filter(fn identity ->
        if is_nil(managed_relationship.lookup_identities) do
          identity.name in List.wrap(opts[:use_identities])
        else
          identity.name in managed_relationship.lookup_identities
        end
      end)
      |> Enum.flat_map(fn identity ->
        identity
        |> Map.get(:keys)
        |> Enum.map(fn key ->
          {identity.name, key}
        end)
      end)
      |> Enum.uniq_by(&elem(&1, 1))
      |> Enum.map(fn {identity_name, key} ->
        attribute = Ash.Resource.Info.attribute(resource, key)

        field = %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: to_string(key),
          identifier: key,
          type: field_type(attribute.type, attribute, resource),
          description: attribute.description || "",
          __reference__: ref(__ENV__)
        }

        {resource, {:identity, identity_name}, field}
      end)
      |> Enum.concat(pkey_fields)
    else
      :none
    end
  end

  defp filter_field_types(resource, schema) do
    filter_attribute_types(resource, schema) ++
      filter_aggregate_types(resource, schema) ++
      List.wrap(calculation_filter_inputs(resource, schema))
  end

  defp filter_attribute_types(resource, schema) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(
      &(AshGraphql.Resource.Info.show_field?(resource, &1.name) && filterable?(&1, resource))
    )
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp filter_aggregate_types(resource, schema) do
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.filter(
      &(AshGraphql.Resource.Info.show_field?(resource, &1.name) && filterable?(&1, resource))
    )
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp attribute_or_aggregate_type(%Ash.Resource.Attribute{type: type}, _resource),
    do: type

  defp attribute_or_aggregate_type(
         %Ash.Resource.Aggregate{kind: kind, field: field, relationship_path: relationship_path},
         resource
       ) do
    field_type =
      with field when not is_nil(field) <- field,
           related when not is_nil(related) <-
             Ash.Resource.Info.related(resource, relationship_path),
           attr when not is_nil(attr) <- Ash.Resource.Info.field(related, field) do
        attr.type
      end

    {:ok, aggregate_type, _} = Ash.Query.Aggregate.kind_to_type(kind, field_type, [])

    aggregate_type
  end

  @doc false
  def filter_type(attribute_or_aggregate, resource, schema) do
    type = attribute_or_aggregate_type(attribute_or_aggregate, resource)

    array_type? = match?({:array, _}, type)

    fields =
      Ash.Filter.builtin_operators()
      |> Enum.concat(Ash.DataLayer.functions(resource))
      |> Enum.filter(& &1.predicate?())
      |> restrict_for_lists(type)
      |> Enum.flat_map(fn operator ->
        filter_fields(operator, type, array_type?, schema, attribute_or_aggregate, resource)
      end)

    if fields == [] do
      []
    else
      identifier = attribute_filter_field_type(resource, attribute_or_aggregate)

      [
        %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
          identifier: identifier,
          fields: fields,
          module: schema,
          name: identifier |> to_string() |> Macro.camelize(),
          __reference__: ref(__ENV__)
        }
      ]
    end
  end

  defp filter_fields(
         operator,
         type,
         array_type?,
         schema,
         attribute_or_aggregate,
         resource
       ) do
    expressable_types = get_expressable_types(operator, type, array_type?)

    if Enum.any?(expressable_types, &(&1 == :same)) do
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: operator.name(),
          module: schema,
          name: to_string(operator.name()),
          type: field_type(type, attribute_or_aggregate, resource, true),
          __reference__: ref(__ENV__)
        }
      ]
    else
      type =
        case Enum.at(expressable_types, 0) do
          [{:array, :any}, :same] ->
            {:unwrap, type}

          [_, {:array, :same}] ->
            {:array, type}

          [_, :same] ->
            type

          [_, :any] ->
            Ash.Type.String

          [_, type] when is_atom(type) ->
            Ash.Type.get_type(type)

          _ ->
            nil
        end

      if type do
        {type, attribute_or_aggregate} =
          case type do
            {:unwrap, type} ->
              {:array, type} = type
              constraints = Map.get(attribute_or_aggregate, :constraints) || []

              {type,
               %{attribute_or_aggregate | type: type, constraints: constraints[:items] || []}}

            type ->
              {type, attribute_or_aggregate}
          end

        if embedded?(type) do
          []
        else
          attribute_or_aggregate = constraints_to_item_constraints(type, attribute_or_aggregate)

          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: operator.name(),
              module: schema,
              name: to_string(operator.name()),
              type: field_type(type, attribute_or_aggregate, resource, true),
              __reference__: ref(__ENV__)
            }
          ]
        end
      else
        []
      end
    end
  rescue
    _e ->
      []
  end

  defp get_expressable_types(operator_or_function, field_type, array_type?) do
    if :attributes
       |> operator_or_function.__info__()
       |> Keyword.get_values(:behaviour)
       |> List.flatten()
       |> Enum.any?(&(&1 == Ash.Query.Operator)) do
      do_get_expressable_types(operator_or_function.types(), field_type, array_type?)
    else
      do_get_expressable_types(operator_or_function.args(), field_type, array_type?)
    end
  end

  defp do_get_expressable_types(operator_types, field_type, array_type?) do
    field_type_short_name =
      case Ash.Type.short_names()
           |> Enum.find(fn {_, type} -> type == field_type end) do
        nil -> nil
        {short_name, _} -> short_name
      end

    operator_types
    |> Enum.filter(fn
      [:any, {:array, type}] when is_atom(type) ->
        true

      [{:array, inner_type}, :same] when is_atom(inner_type) and array_type? ->
        true

      :same ->
        true

      :any ->
        true

      [:any, type] when is_atom(type) ->
        true

      [^field_type_short_name, type] when is_atom(type) and not is_nil(field_type_short_name) ->
        true

      _ ->
        false
    end)
  end

  defp restrict_for_lists(operators, {:array, _}) do
    list_predicates = [Ash.Query.Operator.IsNil, Ash.Query.Operator.Has]
    Enum.filter(operators, &(&1 in list_predicates))
  end

  defp restrict_for_lists(operators, _), do: operators

  defp constraints_to_item_constraints(
         {:array, _},
         %Ash.Resource.Attribute{
           constraints: constraints,
           allow_nil?: allow_nil?
         } = attribute
       ) do
    %{
      attribute
      | constraints: [
          items: constraints,
          nil_items?: allow_nil? || embedded?(attribute.type)
        ]
    }
  end

  defp constraints_to_item_constraints(_, attribute_or_aggregate), do: attribute_or_aggregate

  defp sort_input(resource, schema) do
    if AshGraphql.Resource.Info.type(resource) && AshGraphql.Resource.Info.derive_sort?(resource) do
      case sort_values(resource) do
        [] ->
          nil

        _ ->
          %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
            fields:
              [
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  identifier: :order,
                  module: schema,
                  name: "order",
                  default_value: :asc,
                  type: :sort_order,
                  __reference__: ref(__ENV__)
                },
                %Absinthe.Blueprint.Schema.FieldDefinition{
                  identifier: :field,
                  module: schema,
                  name: "field",
                  type: %Absinthe.Blueprint.TypeReference.NonNull{
                    of_type: resource_sort_field_type(resource)
                  },
                  __reference__: ref(__ENV__)
                }
              ] ++ calc_input_fields(resource, schema),
            identifier: resource_sort_type(resource),
            module: schema,
            name: resource |> resource_sort_type() |> to_string() |> Macro.camelize(),
            __reference__: ref(__ENV__)
          }
      end
    else
      nil
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp calc_input_fields(resource, schema) do
    calcs =
      resource
      |> Ash.Resource.Info.public_calculations()
      |> Enum.filter(&AshGraphql.Resource.Info.show_field?(resource, &1.name))
      |> Enum.reject(fn
        %{type: {:array, _}} ->
          true

        calc ->
          embedded?(calc.type) || Enum.empty?(calc.arguments)
      end)

    field_names = AshGraphql.Resource.Info.field_names(resource)

    Enum.map(calcs, fn calc ->
      input_name = "#{field_names[calc.name] || calc.name}_input"

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: String.to_atom("#{calc.name}_input"),
        module: schema,
        name: input_name,
        type: calc_input_type(calc.name, resource),
        __reference__: ref(__ENV__)
      }
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp calc_input_type(calc, resource) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    String.to_atom(
      "#{AshGraphql.Resource.Info.type(resource)}_#{field_names[calc] || calc}_field_input"
    )
  end

  defp filter_input(resource, schema) do
    if AshGraphql.Resource.Info.derive_filter?(resource) do
      case resource_filter_fields(resource, schema) do
        [] ->
          nil

        fields ->
          %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
            identifier: resource_filter_type(resource),
            module: schema,
            name: resource |> resource_filter_type() |> to_string() |> Macro.camelize(),
            fields: fields,
            __reference__: ref(__ENV__)
          }
      end
    else
      nil
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp calculation_filter_inputs(resource, schema) do
    resource
    |> Ash.Resource.Info.public_calculations()
    |> Enum.flat_map(fn %{calculation: {module, _}} = calculation ->
      Code.ensure_compiled(module)
      filterable? = filterable?(calculation, resource)
      field_type = calculation_type(calculation, resource)

      arguments = calculation_args(calculation, resource, schema)

      array_type? = match?({:array, _}, field_type)

      filter_fields =
        Ash.Filter.builtin_operators()
        |> Enum.concat(Ash.DataLayer.functions(resource))
        |> Enum.filter(& &1.predicate?())
        |> restrict_for_lists(field_type)
        |> Enum.flat_map(
          &filter_fields(
            &1,
            calculation.type,
            array_type?,
            schema,
            calculation,
            resource
          )
        )

      input = %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
        fields: arguments,
        identifier: String.to_atom(to_string(calc_input_type(calculation.name, resource))),
        module: schema,
        name: Macro.camelize(to_string(calc_input_type(calculation.name, resource))),
        __reference__: ref(__ENV__)
      }

      types =
        if Enum.empty?(arguments) do
          []
        else
          [input]
        end

      if filterable? do
        type_def =
          if Enum.empty?(arguments) do
            %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
              fields: filter_fields,
              identifier: calculation_filter_field_type(resource, calculation),
              module: schema,
              name:
                Macro.camelize(to_string(calculation_filter_field_type(resource, calculation))),
              __reference__: ref(__ENV__)
            }
          else
            filter_input_field = %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: :input,
              module: schema,
              name: "input",
              type: String.to_atom(to_string(calc_input_type(calculation.name, resource))),
              __reference__: ref(__ENV__)
            }

            %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
              fields: [filter_input_field | filter_fields],
              identifier: calculation_filter_field_type(resource, calculation),
              module: schema,
              name:
                Macro.camelize(to_string(calculation_filter_field_type(resource, calculation))),
              __reference__: ref(__ENV__)
            }
          end

        [type_def | types]
      else
        types
      end
    end)
  end

  defp resource_filter_fields(resource, schema) do
    boolean_filter_fields(resource, schema) ++
      attribute_filter_fields(resource, schema) ++
      relationship_filter_fields(resource, schema) ++
      aggregate_filter_fields(resource, schema) ++ calculation_filter_fields(resource, schema)
  end

  defp filterable_and_shown_field?(resource, field) do
    AshGraphql.Resource.Info.show_field?(resource, field.name) &&
      AshGraphql.Resource.Info.filterable_field?(resource, field.name)
  end

  defp attribute_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&(filterable_and_shown_field?(resource, &1) && filterable?(&1, resource)))
    |> Enum.flat_map(fn attribute ->
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: attribute.name,
          module: schema,
          name: to_string(field_names[attribute.name] || attribute.name),
          description: attribute.description,
          type: attribute_filter_field_type(resource, attribute),
          __reference__: ref(__ENV__)
        }
      ]
    end)
  end

  defp aggregate_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    if Ash.DataLayer.data_layer_can?(resource, :aggregate_filter) do
      resource
      |> Ash.Resource.Info.public_aggregates()
      |> Enum.filter(&(filterable_and_shown_field?(resource, &1) && filterable?(&1, resource)))
      |> Enum.flat_map(fn aggregate ->
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            identifier: aggregate.name,
            module: schema,
            name: to_string(field_names[aggregate.name] || aggregate.name),
            description: aggregate.description,
            type: attribute_filter_field_type(resource, aggregate),
            __reference__: ref(__ENV__)
          }
        ]
      end)
    else
      []
    end
  end

  defp calculation_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    if Ash.DataLayer.data_layer_can?(resource, :expression_calculation) do
      resource
      |> Ash.Resource.Info.public_calculations()
      |> Enum.filter(&(filterable_and_shown_field?(resource, &1) && filterable?(&1, resource)))
      |> Enum.map(fn calculation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: calculation.name,
          module: schema,
          name: to_string(field_names[calculation.name] || calculation.name),
          description: calculation.description,
          type: calculation_filter_field_type(resource, calculation),
          __reference__: ref(__ENV__)
        }
      end)
    else
      []
    end
  end

  defp filterable?(%Ash.Resource.Aggregate{} = aggregate, resource) do
    attribute =
      with field when not is_nil(field) <- aggregate.field,
           related when not is_nil(related) <-
             Ash.Resource.Info.related(resource, aggregate.relationship_path),
           attr when not is_nil(attr) <- Ash.Resource.Info.field(related, aggregate.field) do
        attr
      end

    field_type =
      if attribute do
        attribute.type
      end

    field_constraints =
      if attribute do
        attribute.constraints
      end

    {:ok, type, constraints} =
      Aggregate.kind_to_type(aggregate.kind, field_type, field_constraints)

    filterable?(
      %Ash.Resource.Attribute{name: aggregate.name, type: type, constraints: constraints},
      resource
    )
  end

  defp filterable?(%{type: {:array, _}}, _), do: false
  defp filterable?(%{filterable?: false}, _), do: false
  defp filterable?(%{type: Ash.Type.Union}, _), do: false

  defp filterable?(%Ash.Resource.Calculation{type: type, calculation: {module, _opts}}, _) do
    !embedded?(type) && module.has_expression?()
  end

  defp filterable?(%{type: type} = attribute, resource) do
    if Ash.Type.NewType.new_type?(type) do
      filterable?(
        %{
          attribute
          | constraints: Ash.Type.NewType.constraints(type, attribute.constraints),
            type: Ash.Type.NewType.subtype_of(type)
        },
        resource
      )
    else
      !embedded?(type)
    end
  end

  defp filterable?(_, _), do: false

  defp sortable?(%Ash.Resource.Aggregate{} = aggregate, resource) do
    attribute =
      with field when not is_nil(field) <- aggregate.field,
           related when not is_nil(related) <-
             Ash.Resource.Info.related(resource, aggregate.relationship_path),
           attr when not is_nil(attr) <- Ash.Resource.Info.field(related, aggregate.field) do
        attr
      end

    field_type =
      if attribute do
        attribute.type
      end

    field_constraints =
      if attribute do
        attribute.constraints
      end

    {:ok, type, constraints} =
      Aggregate.kind_to_type(aggregate.kind, field_type, field_constraints)

    sortable?(
      %Ash.Resource.Attribute{name: aggregate.name, type: type, constraints: constraints},
      resource
    )
  end

  defp sortable?(%{type: {:array, _}}, _), do: false
  defp sortable?(%{sortable?: false}, _), do: false
  defp sortable?(%{type: Ash.Type.Union}, _), do: false

  defp sortable?(%Ash.Resource.Calculation{type: type, calculation: {module, _opts}}, _) do
    !embedded?(type) && module.has_expression?()
  end

  defp sortable?(%{type: type} = attribute, resource) do
    if Ash.Type.NewType.new_type?(type) do
      sortable?(
        %{
          attribute
          | constraints: Ash.Type.NewType.constraints(type, attribute.constraints),
            type: Ash.Type.NewType.subtype_of(type)
        },
        resource
      )
    else
      !embedded?(type)
    end
  end

  defp sortable?(_, _), do: false

  defp relationship_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    relationships = AshGraphql.Resource.Info.relationships(resource)

    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(
      &(filterable_and_shown_field?(resource, &1) &&
          AshGraphql.Resource.Info.derive_filter?(&1.destination) &&
          Resource in Spark.extensions(&1.destination) && &1.name in relationships)
    )
    |> Enum.map(fn relationship ->
      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: relationship.name,
        module: schema,
        name: to_string(field_names[relationship.name] || relationship.name),
        description: relationship.description,
        type: resource_filter_type(relationship.destination),
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp boolean_filter_fields(resource, schema) do
    if Ash.DataLayer.can?(:boolean_filter, resource) do
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: :and,
          module: schema,
          name: "and",
          type: %Absinthe.Blueprint.TypeReference.List{
            of_type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: resource_filter_type(resource)
            }
          },
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: :or,
          module: schema,
          name: "or",
          __reference__: ref(__ENV__),
          type: %Absinthe.Blueprint.TypeReference.List{
            of_type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: resource_filter_type(resource)
            }
          }
        },
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: :not,
          module: schema,
          name: "not",
          type: %Absinthe.Blueprint.TypeReference.List{
            of_type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: resource_filter_type(resource)
            }
          },
          __reference__: ref(__ENV__)
        }
      ]
    else
      []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp resource_sort_field_type(resource) do
    type = AshGraphql.Resource.Info.type(resource)
    String.to_atom(to_string(type) <> "_sort_field")
  end

  def map_definitions(resource, all_domains, schema, env) do
    if AshGraphql.Resource.Info.type(resource) do
      resource
      |> global_maps(all_domains)
      |> Enum.flat_map(fn attribute ->
        type_name =
          if function_exported?(attribute.type, :graphql_type, 1) do
            attribute.type.graphql_type(attribute.constraints)
          end

        input_type_name =
          if function_exported?(attribute.type, :graphql_input_type, 1) do
            attribute.type.graphql_input_type(attribute.constraints)
          end

        description = AshGraphql.Type.description(attribute.type, attribute.constraints)

        constraints = Ash.Type.NewType.constraints(attribute.type, attribute.constraints)

        already_checked =
          if Ash.Type.NewType.new_type?(attribute.type) do
            [attribute.type]
          else
            []
          end

        [
          type_name
        ]
        |> define_map_types(description, constraints, schema, resource, env, already_checked)
        |> Enum.concat(
          [
            input_type_name
          ]
          |> define_input_map_types(
            description,
            constraints,
            schema,
            resource,
            env,
            already_checked
          )
        )
      end)
    else
      []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp define_map_types(
         type_names,
         description,
         constraints,
         schema,
         resource,
         env,
         already_checked
       ) do
    type_names
    |> Enum.filter(& &1)
    |> Enum.flat_map(fn type_name ->
      {types, fields, _} =
        Enum.reduce(
          (constraints[:fields] || []) |> Enum.sort_by(fn {name, _} -> name end),
          {[], [], already_checked},
          fn {name, attribute}, {types, fields, already_checked} ->
            new_type? = Ash.Type.NewType.new_type?(attribute[:type])
            {map_type?, map_type, map_constraints} = map_type(attribute, new_type?)

            map_constraints =
              if new_type? do
                Ash.Type.NewType.constraints(map_type, map_constraints)
              else
                map_constraints
              end

            nested_type_name =
              if new_type? do
                AshGraphql.Type.type(attribute[:type], attribute[:constraints] || [])
              else
                String.to_atom("#{Atom.to_string(type_name)}_#{Atom.to_string(name)}")
              end

            nested_type =
              array_to_list_of(attribute[:type], nested_type_name, attribute[:constraints])

            nested_field =
              %Absinthe.Blueprint.Schema.FieldDefinition{
                module: schema,
                identifier: name,
                __reference__: AshGraphql.Resource.ref(env),
                name: to_string(name),
                description: attribute[:description],
                middleware:
                  middleware_for_field(
                    resource,
                    %{
                      name: name,
                      type: attribute[:type],
                      constraints: attribute[:constraints] || []
                    },
                    name,
                    attribute[:type],
                    attribute[:constraints] || [],
                    nil
                  ),
                type:
                  if Keyword.get(
                       attribute,
                       :allow_nil?,
                       true
                     ) do
                    nested_type
                  else
                    %Absinthe.Blueprint.TypeReference.NonNull{
                      of_type: nested_type
                    }
                  end
              }

            if new_type? && map_type? && map_constraints[:fields] && map_type in already_checked do
              {types, [nested_field | fields], already_checked}
            else
              already_checked =
                if new_type? do
                  [map_type | already_checked]
                else
                  already_checked
                end

              if map_type? && map_constraints[:fields] do
                {
                  define_map_types(
                    [nested_type_name],
                    AshGraphql.Type.description(map_type, map_constraints),
                    map_constraints,
                    schema,
                    resource,
                    env,
                    already_checked
                  ) ++ types,
                  [nested_field | fields],
                  already_checked
                }
              else
                {types,
                 [
                   %Absinthe.Blueprint.Schema.FieldDefinition{
                     module: schema,
                     identifier: name,
                     __reference__: AshGraphql.Resource.ref(env),
                     name: to_string(name),
                     description: attribute[:description],
                     middleware:
                       middleware_for_field(
                         resource,
                         %{
                           name: name,
                           type: attribute[:type],
                           description: attribute[:description],
                           constraints: attribute[:constraints] || []
                         },
                         name,
                         attribute[:type],
                         attribute[:constraints] || [],
                         nil
                       ),
                     type:
                       if Keyword.get(
                            attribute,
                            :allow_nil?,
                            true
                          ) do
                         do_field_type(
                           attribute[:type],
                           %{
                             name: name,
                             type: attribute[:type],
                             description: attribute[:description],
                             constraints: Keyword.get(attribute, :constraints) || []
                           },
                           resource,
                           false
                         )
                       else
                         %Absinthe.Blueprint.TypeReference.NonNull{
                           of_type:
                             do_field_type(
                               attribute[:type],
                               %{
                                 name: name,
                                 type: attribute[:type],
                                 description: attribute[:description],
                                 constraints: Keyword.get(attribute, :constraints) || []
                               },
                               resource,
                               false
                             )
                         }
                       end
                   }
                   | fields
                 ], already_checked}
              end
            end
          end
        )

      [
        %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
          module: schema,
          name: type_name |> to_string() |> Macro.camelize(),
          fields: fields,
          description: description,
          identifier: type_name,
          __reference__: ref(__ENV__)
        }
        | types
      ]
    end)
  end

  defp map_type(attribute, new_type?) do
    case attribute[:type] do
      {:array, type} ->
        attribute
        |> Keyword.put(:type, type)
        |> Keyword.update(:constraints, [], &(&1[:items] || []))
        |> map_type(new_type?)

      type ->
        {type in [:map, Ash.Type.Map, :struct, Ash.Type.Struct] ||
           (new_type? &&
              Ash.Type.NewType.subtype_of(type) in [
                :map,
                Ash.Type.Map,
                :struct,
                Ash.Type.Struct
              ]), type, attribute[:constraints] || []}
    end
  end

  defp array_to_list_of({:array, type}, nested_type_name, constraints) do
    nil_items? = Keyword.get(constraints || [], :nil_items?, true)

    inner_type = array_to_list_of(type, nested_type_name, constraints[:items] || [])

    %Absinthe.Blueprint.TypeReference.List{
      of_type:
        if nil_items? do
          inner_type
        else
          %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: inner_type
          }
        end
    }
  end

  defp array_to_list_of(_type, nested_type_name, _constraints) do
    nested_type_name
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp define_input_map_types(
         input_type_names,
         description,
         constraints,
         schema,
         resource,
         env,
         already_checked
       ) do
    input_type_names
    |> Enum.filter(& &1)
    |> Enum.flat_map(fn type_name ->
      {types, fields, _} =
        Enum.reduce(
          constraints[:fields] |> Enum.sort_by(fn {name, _} -> name end),
          {[], [], already_checked},
          fn
            {name, attribute}, {types, fields, already_checked} ->
              new_type? = Ash.Type.NewType.new_type?(attribute[:type])
              {map_type?, map_type, map_constraints} = map_type(attribute, new_type?)

              map_constraints =
                if new_type? do
                  Ash.Type.NewType.constraints(map_type, map_constraints)
                else
                  map_constraints
                end

              nested_type_name =
                if new_type? do
                  AshGraphql.Type.input_type(attribute[:type], attribute[:constraints] || [])
                else
                  String.to_atom(
                    "#{Atom.to_string(type_name) |> String.replace("_input", "")}_#{Atom.to_string(name)}_input"
                  )
                end

              nested_type =
                array_to_list_of(attribute[:type], nested_type_name, attribute[:constraints])

              nested_field =
                %Absinthe.Blueprint.Schema.InputValueDefinition{
                  module: schema,
                  identifier: name,
                  description: attribute[:description],
                  __reference__: AshGraphql.Resource.ref(env),
                  name: to_string(name),
                  type:
                    if Keyword.get(attribute, :allow_nil?, true) do
                      nested_type
                    else
                      %Absinthe.Blueprint.TypeReference.NonNull{
                        of_type: nested_type
                      }
                    end
                }

              field_type =
                do_field_type(
                  attribute[:type],
                  %{
                    name: name,
                    type: attribute[:type],
                    description: attribute[:description],
                    constraints: Keyword.get(attribute, :constraints) || []
                  },
                  resource,
                  true
                )

              typed_field =
                %Absinthe.Blueprint.Schema.InputValueDefinition{
                  module: schema,
                  identifier: name,
                  __reference__: AshGraphql.Resource.ref(env),
                  name: to_string(name),
                  description: attribute[:description],
                  type:
                    if Keyword.get(attribute, :allow_nil?, true) do
                      field_type
                    else
                      %Absinthe.Blueprint.TypeReference.NonNull{of_type: field_type}
                    end
                }

              if new_type? && map_type in already_checked do
                if map_type? && map_constraints[:fields] do
                  {types, [nested_field | fields], already_checked}
                else
                  {types, [typed_field | fields], already_checked}
                end
              else
                already_checked =
                  if new_type? do
                    [map_type | already_checked]
                  else
                    already_checked
                  end

                if map_type? && map_constraints[:fields] do
                  {
                    define_input_map_types(
                      [nested_type_name],
                      AshGraphql.Type.description(map_type, map_constraints),
                      map_constraints,
                      schema,
                      resource,
                      env,
                      already_checked
                    ) ++ types,
                    [nested_field | fields],
                    already_checked
                  }
                else
                  {types, [typed_field | fields], already_checked}
                end
              end
          end
        )

      [
        %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
          module: schema,
          name: type_name |> to_string() |> Macro.camelize(),
          fields: fields,
          description: description,
          identifier: type_name,
          __reference__: ref(__ENV__)
        }
        | types
      ]
    end)
  end

  def enum_definitions(resource, schema, env) do
    resource = Ash.Type.NewType.subtype_of(resource)

    if AshGraphql.Resource.Info.type(resource) && AshGraphql.Resource.Info.derive_sort?(resource) do
      sort_values = sort_values(resource)

      sort_order = %Absinthe.Blueprint.Schema.EnumTypeDefinition{
        module: schema,
        name: resource |> resource_sort_field_type() |> to_string() |> Macro.camelize(),
        identifier: resource_sort_field_type(resource),
        __reference__: ref(__ENV__),
        values:
          Enum.map(sort_values, fn {sort_value_alias, sort_value} ->
            %Absinthe.Blueprint.Schema.EnumValueDefinition{
              module: schema,
              identifier: sort_value_alias,
              __reference__: AshGraphql.Resource.ref(env),
              name: String.upcase(to_string(sort_value_alias)),
              value: sort_value
            }
          end)
      }

      [sort_order]
    else
      []
    end
  end

  @doc false
  # sobelow_skip ["RCE.CodeModule", "DOS.BinToAtom", "DOS.StringToAtom"]
  def union_type_definitions(resource, attribute, type_name, schema, env, input_type_name) do
    grapqhl_unnested_unions =
      if function_exported?(attribute.type, :graphql_unnested_unions, 1) do
        attribute.type.graphql_unnested_unions(attribute.constraints)
      else
        []
      end

    constraints = Ash.Type.NewType.constraints(attribute.type, attribute.constraints)

    names_to_field_types =
      Map.new(constraints[:types] || %{}, fn {name, config} ->
        {name,
         field_type(
           config[:type],
           %{
             attribute
             | name: nested_union_type_name(attribute, name),
               constraints: config[:constraints],
               description: config[:description]
           },
           resource,
           false
         )}
      end)

    func_name = :"resolve_gql_union_#{type_name}"

    {func, _} =
      Code.eval_quoted(
        {:&, [],
         [
           {:/, [],
            [
              {{:., [], [schema, func_name]}, [], []},
              2
            ]}
         ]},
        []
      )

    input_definitions = [
      %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
        module: schema,
        name: input_type_name |> to_string() |> Macro.camelize(),
        identifier: String.to_atom(to_string(input_type_name)),
        __reference__: ref(env),
        description: AshGraphql.Type.description(attribute.type, attribute.constraints),
        fields:
          Enum.map(constraints[:types] |> Enum.sort_by(fn {name, _} -> name end), fn {name,
                                                                                      config} ->
            %Absinthe.Blueprint.Schema.InputValueDefinition{
              name: name |> to_string(),
              identifier: name,
              __reference__: ref(env),
              description: config[:description],
              type:
                field_type(
                  config[:type],
                  %{attribute | name: String.to_atom("#{attribute.name}_#{name}")},
                  resource,
                  true,
                  warn_unknown?: false
                )
            }
          end)
      }
    ]

    object_type_definitions =
      constraints[:types]
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.reject(fn {name, _} ->
        name in grapqhl_unnested_unions
      end)
      |> Enum.map(fn {name, config} ->
        %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
          module: schema,
          name: "#{type_name}_#{name}" |> Macro.camelize(),
          identifier: :"#{type_name}_#{name}",
          __reference__: ref(env),
          description: config[:description],
          fields: [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: :value,
              module: schema,
              name: "value",
              __reference__: ref(env),
              type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: names_to_field_types[name]
              }
            }
          ]
        }
      end)

    [
      %Absinthe.Blueprint.Schema.UnionTypeDefinition{
        module: schema,
        name: type_name |> to_string() |> Macro.camelize(),
        resolve_type: func,
        description: AshGraphql.Type.description(attribute.type, attribute.constraints),
        types:
          Enum.map(constraints[:types] |> Enum.sort_by(fn {name, _} -> name end), fn {name,
                                                                                      _config} ->
            if name in grapqhl_unnested_unions do
              %Absinthe.Blueprint.TypeReference.Name{
                name: to_string(names_to_field_types[name]) |> Macro.camelize()
              }
            else
              %Absinthe.Blueprint.TypeReference.Name{
                name: "#{type_name}_#{name}" |> Macro.camelize()
              }
            end
          end),
        identifier: type_name,
        __reference__: ref(env)
      }
    ] ++
      input_definitions ++
      object_type_definitions
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def nested_union_type_name(attribute, name, existing_only? \\ false) do
    str = "#{attribute.name}_#{name}"

    if existing_only? do
      String.to_existing_atom(str)
    else
      String.to_atom(str)
    end
  end

  @doc false
  def global_maps(resource, all_domains) do
    resource
    |> AshGraphql.all_attributes_and_arguments(all_domains)
    |> Enum.map(&unnest/1)
    |> Enum.filter(
      &(Ash.Type.NewType.subtype_of(&1.type) in [Ash.Type.Map, Ash.Type.Struct] &&
          !Enum.empty?(Ash.Type.NewType.constraints(&1.type, &1.constraints)[:fields] || []) &&
          define_type?(&1.type, &1.constraints))
    )
  end

  @spec define_type?(Ash.Type.t(), Ash.Type.constraints()) :: boolean()
  def define_type?({:array, type}, constraints), do: define_type?(type, constraints)

  def define_type?(type, constraints) do
    type = Ash.Type.get_type(type)

    if function_exported?(type, :graphql_define_type?, 1) do
      type.graphql_define_type?(constraints)
    else
      true
    end
  end

  @doc false
  def unnest(%{type: {:array, type}, constraints: constraints} = attribute) do
    unnest(%{attribute | type: type, constraints: constraints[:items] || []})
  end

  def unnest(other), do: other

  @doc false
  def global_unions(resource, all_domains) do
    resource
    |> AshGraphql.all_attributes_and_arguments(all_domains)
    |> Enum.filter(&define_type?(&1.type, &1.constraints))
    |> AshGraphql.only_union_types()
    |> Enum.uniq_by(&elem(&1, 0))
  end

  defp sort_values(resource) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(Ash.Resource.Info.public_calculations(resource))
    |> Enum.concat(Ash.Resource.Info.public_aggregates(resource))
    |> Enum.filter(
      &(AshGraphql.Resource.Info.show_field?(resource, &1.name) &&
          AshGraphql.Resource.Info.sortable_field?(resource, &1.name) &&
          sortable?(&1, resource))
    )
    |> Enum.map(& &1.name)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      {field_names[name] || name, name}
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp relay_page(type, schema, countable?) do
    [
      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "#{inspect(type)} edge",
        fields: [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "Cursor",
            identifier: :cursor,
            module: schema,
            name: "cursor",
            __reference__: ref(__ENV__),
            type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: :string
            }
          },
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "#{inspect(type)} node",
            identifier: :node,
            module: schema,
            name: "node",
            __reference__: ref(__ENV__),
            type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: type
            }
          }
        ],
        identifier: String.to_atom("#{type}_edge"),
        module: schema,
        name: Macro.camelize("#{type}_edge"),
        __reference__: ref(__ENV__)
      },
      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "#{inspect(type)} connection",
        fields:
          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: "Page information",
              identifier: :page_info,
              module: schema,
              name: "page_info",
              __reference__: ref(__ENV__),
              type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: :page_info
              }
            },
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: "#{inspect(type)} edges",
              identifier: :edges,
              module: schema,
              name: "edges",
              __reference__: ref(__ENV__),
              type: %Absinthe.Blueprint.TypeReference.List{
                of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                  of_type: String.to_atom("#{type}_edge")
                }
              }
            }
          ]
          |> add_count_to_page(schema, countable?),
        identifier: String.to_atom("#{type}_connection"),
        module: schema,
        name: Macro.camelize("#{type}_connection"),
        __reference__: ref(__ENV__)
      }
    ]
  end

  defp add_pagination_metadata(fields, schema, true) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Whether or not there is a next page",
        identifier: :has_next_page,
        module: schema,
        name: "has_next_page",
        __reference__: ref(__ENV__),
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :boolean}
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Whether or not there is a previous page",
        identifier: :has_previous_page,
        module: schema,
        name: "has_previous_page",
        __reference__: ref(__ENV__),
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :boolean}
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The number of the current page",
        identifier: :page_number,
        module: schema,
        name: "page_number",
        __reference__: ref(__ENV__),
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :integer}
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The number of the last page",
        identifier: :last_page,
        module: schema,
        name: "last_page",
        __reference__: ref(__ENV__),
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :integer}
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The number of records per page",
        identifier: :limit,
        module: schema,
        name: "limit",
        __reference__: ref(__ENV__),
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :integer}
      }
      | fields
    ]
  end

  defp add_pagination_metadata(fields, _, _), do: fields

  defp add_count_to_page(fields, schema, true) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Total count on all pages",
        identifier: :count,
        module: schema,
        name: "count",
        __reference__: ref(__ENV__),
        type: :integer
      }
      | fields
    ]
  end

  defp add_count_to_page(fields, _, _), do: fields

  # sobelow_skip ["DOS.StringToAtom"]
  defp page_of(type, schema, countable?) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "A page of #{inspect(type)}",
      fields:
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The records contained in the page",
            identifier: :results,
            module: schema,
            name: "results",
            __reference__: ref(__ENV__),
            type: %Absinthe.Blueprint.TypeReference.List{
              of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: type
              }
            }
          }
        ]
        |> add_count_to_page(schema, countable?)
        |> add_pagination_metadata(schema, countable?),
      identifier: String.to_atom("page_of_#{type}"),
      module: schema,
      name: Macro.camelize("page_of_#{type}"),
      __reference__: ref(__ENV__)
    }
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp keyset_page_of(type, schema, countable?) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "A keyset page of #{inspect(type)}",
      fields:
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The records contained in the page",
            identifier: :results,
            module: schema,
            name: "results",
            __reference__: ref(__ENV__),
            type: %Absinthe.Blueprint.TypeReference.List{
              of_type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: type
              }
            }
          },
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The first keyset in the results",
            identifier: :start_keyset,
            module: schema,
            name: "start_keyset",
            type: :string,
            __reference__: ref(__ENV__)
          },
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The last keyset in the results",
            identifier: :end_keyset,
            module: schema,
            name: "end_keyset",
            type: :string,
            __reference__: ref(__ENV__)
          }
        ]
        |> add_count_to_page(schema, countable?),
      identifier: String.to_atom("keyset_page_of_#{type}"),
      module: schema,
      name: Macro.camelize("keyset_page_of_#{type}"),
      __reference__: ref(__ENV__)
    }
  end

  defp page_type_definitions(resource, schema) do
    type = AshGraphql.Resource.Info.type(resource)

    paginatable? =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.any?(fn action ->
        action.type == :read && action.pagination
      end)

    countable? =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.any?(fn action ->
        action.type == :read && action.pagination && action.pagination.countable
      end)

    if type && paginatable? do
      List.wrap(page_of(type, schema, countable?)) ++
        List.wrap(keyset_page_of(type, schema, countable?)) ++
        List.wrap(relay_page(type, schema, countable?))
    else
      nil
    end
  end

  def node_type?(type) do
    type.identifier == :node
  end

  def query_type_definitions(resource, domain, all_domains, schema, relay_ids?) do
    resource_type = AshGraphql.Resource.Info.type(resource)

    resource
    |> AshGraphql.Resource.Info.queries(domain)
    |> Enum.filter(&(Map.get(&1, :type_name) && &1.type_name != resource_type))
    |> Enum.map(fn query ->
      relay? = Map.get(query, :relay?)

      # We can implement the Relay node interface only if the resource has a get
      # query using the primary key as identity
      interfaces =
        if relay? and primary_key_get_query(resource, all_domains) != nil do
          [:node]
        else
          []
        end

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: Ash.Resource.Info.description(resource),
        interfaces: interfaces,
        fields: fields(resource, domain, schema, relay_ids?, query),
        identifier: query.type_name,
        module: schema,
        name: Macro.camelize(to_string(query.type_name)),
        __reference__: ref(__ENV__)
      }
    end)
  end

  def type_definition(resource, domain, all_domains, schema, relay_ids?) do
    actual_resource = Ash.Type.NewType.subtype_of(resource)

    if generate_object?(resource, all_domains) do
      type =
        AshGraphql.Resource.Info.type(resource) ||
          raise """
          Resource #{inspect(resource)} needs to generate its GraphQL type but doesn't have a type
          configured in its `graphql` section.

          To fix this do one of the following:

          1) Define the type of your resource with `type :your_resource_type` to let Ash generate it.

          2) Pass both `generate_object? false` and `type :your_resource_type` to manually define
          your resource type using Absinthe.

          3) Pass only `generate_object? false` to skip the resource type entirely. This means that
          you can only use actions which don't require the type (e.g. `action` queries).
          """

      resource = actual_resource

      relay? =
        resource
        |> queries(all_domains)
        |> Enum.any?(&Map.get(&1, :relay?))
        |> Kernel.or(relay_ids?)

      # We can implement the Relay node interface only if the resource has a get
      # query using the primary key as identity
      interfaces =
        if relay? and primary_key_get_query(resource, all_domains) != nil do
          [:node]
        else
          []
        end

      case fields(resource, domain, schema, relay_ids?) do
        [] ->
          raise """
          The resource #{inspect(resource)} does not have any visible fields in GraphQL.

          This typically means that there are no public fields on the resource in question.
          """

        fields ->
          %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
            description: Ash.Resource.Info.description(resource),
            interfaces: interfaces,
            fields: fields,
            identifier: type,
            module: schema,
            name: Macro.camelize(to_string(type)),
            __reference__: ref(__ENV__)
          }
      end
    end
  end

  defp generate_object?(resource, all_domains) do
    cond do
      AshGraphql.Resource.Info.type(resource) ->
        generate_object?(resource)

      !generate_object?(resource) ->
        false

      referenced_by_action(resource) ->
        generate_object?(resource)

      referenced_by_type?(resource, all_domains) ->
        true

      referenced_by_relationship?(resource, all_domains) ->
        true

      true ->
        false
    end
  end

  defp referenced_by_action(resource) do
    Enum.any?(
      AshGraphql.Resource.Info.queries(resource) ++ AshGraphql.Resource.Info.mutations(resource),
      &(&1.type != :action)
    )
  end

  defp referenced_by_relationship?(resource, all_domains) do
    all_domains
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(&AshGraphql.Resource.Info.type(&1))
    |> Enum.flat_map(&Ash.Resource.Info.public_relationships/1)
    |> Enum.any?(&(&1.destination == resource))
  end

  defp referenced_by_type?(resource, all_domains) do
    resource
    |> AshGraphql.all_attributes_and_arguments(all_domains)
    |> Enum.map(&AshGraphql.Resource.unnest/1)
    |> Enum.any?(fn %{type: type, constraints: constraints} ->
      type == :struct and constraints[:instance_of] == resource
    end)
  end

  defp fields(resource, domain, schema, relay_ids?, query \\ nil) do
    attributes(resource, domain, schema, relay_ids?) ++
      metadata(query, resource, schema) ++
      relationships(resource, domain, schema) ++
      aggregates(resource, domain, schema) ++
      calculations(resource, domain, schema) ++
      keyset(resource, schema)
  end

  defp metadata(nil, _resource, _schema) do
    []
  end

  defp metadata(query, resource, schema) do
    action = Ash.Resource.Info.action(resource, query.action)
    show_metadata = query.show_metadata || Enum.map(Map.get(action, :metadata, []), & &1.name)

    action.metadata
    |> Enum.filter(&(&1.name in show_metadata))
    |> Enum.map(fn metadata ->
      field_type =
        case query.metadata_types[metadata.name] do
          nil ->
            metadata.type
            |> field_type(metadata, resource)
            |> maybe_wrap_non_null(not metadata.allow_nil?)

          type ->
            unwrap_literal_type(type)
        end

      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: metadata.description,
        identifier: metadata.name,
        module: schema,
        name: to_string(query.metadata_names[metadata.name] || metadata.name),
        type: field_type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp keyset(resource, schema) do
    case AshGraphql.Resource.Info.keyset_field(resource) do
      nil ->
        []

      field ->
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The pagination #{field}.",
            identifier: field,
            module: schema,
            middleware: [
              {{AshGraphql.Graphql.Resolver, :resolve_keyset}, field}
            ],
            name: to_string(field),
            type: :string,
            __reference__: ref(__ENV__)
          }
        ]
    end
  end

  defp attributes(resource, domain, schema, relay_ids?) do
    attribute_names = AshGraphql.Resource.Info.field_names(resource)

    attributes =
      if AshGraphql.Resource.Info.encode_primary_key?(resource) do
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.reject(&(&1.name == :id))
      else
        Ash.Resource.Info.public_attributes(resource)
      end

    attributes =
      attributes
      |> Enum.filter(&AshGraphql.Resource.Info.show_field?(resource, &1.name))
      |> Enum.map(fn attribute ->
        field_type =
          attribute.type
          |> field_type(attribute, resource)
          |> maybe_wrap_non_null(
            not (nullable_field?(resource, attribute.name) or attribute.allow_nil?)
          )

        name = attribute_names[attribute.name] || attribute.name

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          middleware:
            middleware_for_field(
              resource,
              attribute,
              attribute.name,
              attribute.type,
              attribute.constraints,
              domain
            ),
          name: to_string(name),
          type: field_type,
          __reference__: ref(__ENV__)
        }
      end)

    if relay_ids? or AshGraphql.Resource.Info.encode_primary_key?(resource) do
      encoded_id(resource, schema, relay_ids?) ++
        attributes
    else
      attributes
    end
  end

  defp encoded_id(resource, schema, relay_ids?) do
    case Ash.Resource.Info.primary_key(resource) do
      [] ->
        []

      [field] ->
        attribute = Ash.Resource.Info.attribute(resource, field)

        if attribute.public? do
          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: attribute.description,
              identifier: :id,
              module: schema,
              name: "id",
              type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
              middleware: [
                {{AshGraphql.Graphql.Resolver, :resolve_id}, {resource, field, relay_ids?}}
              ],
              __reference__: ref(__ENV__)
            }
          ]
        else
          []
        end

      fields ->
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "A unique identifier",
            identifier: :id,
            module: schema,
            name: "id",
            type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
            middleware: [
              {{AshGraphql.Graphql.Resolver, :resolve_composite_id},
               {resource, fields, relay_ids?}}
            ],
            __reference__: ref(__ENV__)
          }
        ]
    end
  end

  defp pkey_fields(resource, schema, require?) do
    encode? = AshGraphql.Resource.Info.encode_primary_key?(resource)

    case Ash.Resource.Info.primary_key(resource) do
      [field] when encode? ->
        attribute = Ash.Resource.Info.attribute(resource, field)
        field_type = maybe_wrap_non_null(:id, require?)

        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: attribute.description,
            identifier: field,
            module: schema,
            name: to_string(attribute.name),
            type: field_type,
            __reference__: ref(__ENV__)
          }
        ]

      fields ->
        for field <- fields do
          attribute = Ash.Resource.Info.attribute(resource, field)

          field_type =
            attribute.type
            |> field_type(attribute, resource)
            |> maybe_wrap_non_null(require?)

          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: attribute.description,
            identifier: attribute.name,
            module: schema,
            name: to_string(attribute.name),
            type: field_type,
            __reference__: ref(__ENV__)
          }
        end
    end
  end

  defp argument_required?(%{allow_nil?: true}), do: false
  defp argument_required?(%{default: default}) when not is_nil(default), do: false
  defp argument_required?(_), do: true

  # sobelow_skip ["DOS.StringToAtom"]
  defp relationships(resource, domain, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    relationships = AshGraphql.Resource.Info.relationships(resource)

    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      AshGraphql.Resource.Info.show_field?(resource, relationship.name) &&
        Resource in Spark.extensions(relationship.destination) &&
        relationship.name in relationships &&
        AshGraphql.Resource.Info.type(relationship.destination)
    end)
    |> Enum.map(fn
      %{cardinality: :one} = relationship ->
        name = field_names[relationship.name] || relationship.name

        type =
          relationship.destination
          |> AshGraphql.Resource.Info.type()
          |> maybe_wrap_non_null(
            not (nullable_field?(resource, relationship.name) or relationship.allow_nil?)
          )

        read_action =
          if relationship.read_action do
            Ash.Resource.Info.action(relationship.destination, relationship.read_action)
          else
            Ash.Resource.Info.primary_action!(relationship.destination, :read)
          end

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(name),
          description: relationship.description,
          arguments: args(:one_related, relationship.destination, read_action, schema),
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc_one}, {domain, relationship}}
          ],
          type: type,
          __reference__: ref(__ENV__)
        }

      %{cardinality: :many} = relationship ->
        name = field_names[relationship.name] || relationship.name

        read_action =
          if relationship.read_action do
            Ash.Resource.Info.action(relationship.destination, relationship.read_action)
          else
            Ash.Resource.Info.primary_action!(relationship.destination, :read)
          end

        type = AshGraphql.Resource.Info.type(relationship.destination)
        type_complexity = AshGraphql.Resource.Info.complexity(relationship.destination)

        pagination_strategy =
          relationship_pagination_strategy(resource, relationship.name, read_action)

        query_type = related_list_type(pagination_strategy, type, resource, relationship)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(name),
          description: relationship.description,
          complexity: type_complexity || {AshGraphql.Graphql.Resolver, :query_complexity},
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc_many},
             {domain, relationship, pagination_strategy}}
          ],
          arguments:
            related_list_args(
              resource,
              relationship.destination,
              relationship.name,
              read_action,
              schema
            ),
          type: query_type,
          __reference__: ref(__ENV__)
        }
    end)
  end

  defp related_list_type(value, type, resource, relationship)
       when is_nil(value) or value == :none do
    inner_type = %Absinthe.Blueprint.TypeReference.List{
      of_type: %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: type
      }
    }

    if nullable_field?(resource, relationship.name) do
      inner_type
    else
      %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: inner_type
      }
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp related_list_type(:relay, type, resource, relationship) do
    inner_type = String.to_atom("#{type}_connection")

    if nullable_field?(resource, relationship.name) do
      inner_type
    else
      %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: inner_type
      }
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp related_list_type(:keyset, type, resource, relationship) do
    inner_type = String.to_atom("keyset_page_of_#{type}")

    if nullable_field?(resource, relationship.name) do
      inner_type
    else
      %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: inner_type
      }
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp related_list_type(:offset, type, resource, relationship) do
    inner_type = String.to_atom("page_of_#{type}")

    if nullable_field?(resource, relationship.name) do
      inner_type
    else
      %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: inner_type
      }
    end
  end

  defp nullable_field?(resource, field) do
    field in AshGraphql.Resource.Info.nullable_fields(resource)
  end

  defp aggregates(resource, domain, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.filter(&AshGraphql.Resource.Info.show_field?(resource, &1.name))
    |> Enum.map(fn aggregate ->
      name = field_names[aggregate.name] || aggregate.name

      {field, field_type, constraints} =
        with field when not is_nil(field) <- aggregate.field,
             related when not is_nil(related) <-
               Ash.Resource.Info.related(resource, aggregate.relationship_path),
             attr when not is_nil(attr) <- Ash.Resource.Info.field(related, aggregate.field) do
          {attr, attr.type, attr.constraints}
        else
          _ ->
            {nil, nil, []}
        end

      {:ok, agg_type, constraints} =
        Aggregate.kind_to_type(aggregate.kind, field_type, constraints)

      attribute = field || Map.put(aggregate, :constraints, constraints)

      type =
        if is_nil(Ash.Query.Aggregate.default_value(aggregate.kind)) ||
             nullable_field?(resource, attribute.name) do
          resource =
            if field do
              Ash.Resource.Info.related(resource, aggregate.relationship_path)
            else
              resource
            end

          field_type(agg_type, attribute, resource)
        else
          resource =
            if field && aggregate.type in [:first, :list] do
              Ash.Resource.Info.related(resource, aggregate.relationship_path)
            else
              resource
            end

          %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: field_type(agg_type, attribute, resource)
          }
        end

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: aggregate.name,
        module: schema,
        middleware:
          middleware_for_field(resource, aggregate, aggregate.name, agg_type, constraints, domain),
        name: to_string(name),
        description: aggregate.description,
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp middleware_for_field(resource, field, name, {:array, type}, constraints, domain) do
    case middleware_for_field(resource, field, name, type, constraints, domain) do
      [{middleware, {name, type, field, resource, unnested_types, domain}}] ->
        [{middleware, {name, {:array, type}, field, resource, unnested_types, domain}}]

      middleware ->
        middleware
    end
  end

  defp middleware_for_field(resource, field, name, type, constraints, domain) do
    if Ash.Type.NewType.new_type?(type) &&
         Ash.Type.NewType.subtype_of(type) == Ash.Type.Union &&
         function_exported?(type, :graphql_unnested_unions, 1) do
      unnested_types = type.graphql_unnested_unions(constraints)

      [
        {{AshGraphql.Graphql.Resolver, :resolve_union},
         {name, type, field, resource, unnested_types, domain}}
      ]
    else
      [
        {{AshGraphql.Graphql.Resolver, :resolve_attribute}, {name, type, constraints, domain}}
      ]
    end
  end

  defp calculations(resource, domain, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_calculations()
    |> Enum.filter(&AshGraphql.Resource.Info.show_field?(resource, &1.name))
    |> Enum.map(fn calculation ->
      name = field_names[calculation.name] || calculation.name
      field_type = calculation_type(calculation, resource)

      arguments = calculation_args(calculation, resource, schema)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: calculation.name,
        module: schema,
        arguments: arguments,
        complexity: 2,
        middleware: [
          {{AshGraphql.Graphql.Resolver, :resolve_calculation}, {domain, resource, calculation}}
        ],
        name: to_string(name),
        description: calculation.description,
        type: field_type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp calculation_type(calculation, resource) do
    calculation.type
    |> Ash.Type.get_type()
    |> field_type(calculation, resource)
    |> maybe_wrap_non_null(
      not (nullable_field?(resource, calculation.name) or calculation.allow_nil?)
    )
  end

  defp calculation_args(calculation, resource, schema) do
    Enum.map(calculation.arguments, fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(argument.name),
        # Will be replaced with `argument.description`.
        description: Map.get(argument, :description),
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  @doc false
  def field_type(type, field, resource, input? \\ false, opts \\ []) do
    case field do
      %Ash.Resource.Attribute{name: name} ->
        override =
          if input? do
            AshGraphql.Resource.Info.attribute_input_types(resource)[name]
          else
            AshGraphql.Resource.Info.attribute_types(resource)[name]
          end

        if override do
          unwrap_literal_type(override)
        else
          do_field_type(type, field, resource, input?, nil, opts)
        end

      _ ->
        do_field_type(type, field, resource, input?, nil, opts)
    end
  end

  defp do_field_type(type, field, resource, input?, constraints \\ nil, opts \\ [])

  defp do_field_type(
         {:array, type},
         %Ash.Resource.Aggregate{kind: :list} = aggregate,
         resource,
         input?,
         _,
         opts
       ) do
    with related when not is_nil(related) <-
           Ash.Resource.Info.related(resource, aggregate.relationship_path),
         attr when not is_nil(related) <- Ash.Resource.Info.attribute(related, aggregate.field) do
      if attr.allow_nil? do
        %Absinthe.Blueprint.TypeReference.List{
          of_type: do_field_type(type, aggregate, resource, input?, opts)
        }
      else
        %Absinthe.Blueprint.TypeReference.List{
          of_type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: do_field_type(type, aggregate, resource, input?, opts)
          }
        }
      end
    end
  end

  defp do_field_type(
         {:array, type},
         %Ash.Resource.Aggregate{} = aggregate,
         resource,
         input?,
         _,
         opts
       ) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: do_field_type(type, aggregate, resource, input?, opts)
    }
  end

  defp do_field_type({:array, type}, nil, resource, input?, constraints, opts) do
    # Due to ash not automatically adding the default array constraints to
    # types defined outside of an `attribute` we need to default to true here
    # and not to false.
    nil_items? = Keyword.get(constraints || [], :nil_items?, true)

    field_type =
      do_field_type(type, nil, resource, input?, constraints[:items] || [], opts)
      |> maybe_wrap_non_null(!nil_items?)

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  defp do_field_type({:array, type}, attribute, resource, input?, _, opts) do
    new_constraints = attribute.constraints[:items] || []
    new_attribute = %{attribute | constraints: new_constraints, type: type}

    field_type =
      type
      |> do_field_type(new_attribute, resource, input?, new_constraints, opts)
      |> maybe_wrap_non_null(!attribute.constraints[:nil_items?] || embedded?(attribute.type))

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp do_field_type(type, attribute, resource, input?, constraints, opts) do
    type = Ash.Type.get_type(type)

    constraints =
      case attribute do
        %{constraints: constraints} -> constraints
        _ -> constraints
      end || []

    if Ash.Type.builtin?(type) do
      get_specific_field_type(type, attribute, resource, input?)
    else
      if Ash.Resource.Info.resource?(type) && !Ash.Resource.Info.embedded?(type) do
        if input? do
          Application.get_env(:ash_graphql, :json_type) || :json_string
        else
          AshGraphql.Resource.Info.type(type) || Application.get_env(:ash_graphql, :json_type) ||
            :json_string
        end
      else
        if Ash.Type.embedded_type?(type) do
          if input? && type(type) do
            case embedded_type_input(resource, attribute, type, nil) do
              nil ->
                if Keyword.get(opts, :warn_unknown?, true) do
                  IO.warn(
                    "Embedded type #{inspect(type)} does not have an input type defined, but is accepted as input in at least one location."
                  )
                end

                Application.get_env(:ash_graphql, :json_type) || :json_string

              type ->
                type.identifier
            end
          else
            case type(type) do
              nil ->
                Application.get_env(:ash_graphql, :json_type) || :json_string

              type ->
                type
            end
          end
        else
          if Spark.implements_behaviour?(type, Ash.Type.Enum) do
            if function_exported?(type, :graphql_type, 1) do
              type.graphql_type(constraints)
            else
              :string
            end
          else
            function =
              if input? do
                :graphql_input_type
              else
                :graphql_type
              end

            cond do
              function_exported?(type, function, 1) ->
                apply(type, function, [constraints])

              input? && Ash.Type.NewType.new_type?(type) &&
                Ash.Type.NewType.subtype_of(type) == Ash.Type.Union &&
                  function_exported?(type, :graphql_type, 1) ->
                :"#{type.graphql_type(constraints)}_input"

              true ->
                if Ash.Type.NewType.new_type?(type) do
                  subtype_of = Ash.Type.NewType.subtype_of(type)

                  do_field_type(
                    subtype_of,
                    %{
                      attribute
                      | type: subtype_of,
                        constraints: Ash.Type.NewType.constraints(type, constraints)
                    },
                    resource,
                    input?,
                    opts
                  )
                else
                  raise """
                  Could not determine graphql type for #{inspect(type)}, please define: #{function}/1!
                  """
                end
            end
          end
        end
      end
    end
  end

  defp get_specific_field_type(
         Ash.Type.Atom,
         _,
         _resource,
         _input?
       ) do
    :string
  end

  defp get_specific_field_type(
         Ash.Type.Map,
         _attribute,
         _resource,
         _input?
       ) do
    Application.get_env(:ash_graphql, :json_type) || :json_string
  end

  defp get_specific_field_type(Ash.Type.Boolean, _, _, _), do: :boolean

  defp get_specific_field_type(Ash.Type.CiString, _, _, _), do: :string
  defp get_specific_field_type(Ash.Type.Date, _, _, _), do: :date
  defp get_specific_field_type(Ash.Type.Decimal, _, _, _), do: :decimal
  defp get_specific_field_type(Ash.Type.Integer, _, _, _), do: :integer
  defp get_specific_field_type(Ash.Type.DurationName, _, _, _), do: :duration_name

  defp get_specific_field_type(Ash.Type.String, _, _, _), do: :string
  defp get_specific_field_type(Ash.Type.Term, _, _, _), do: :string

  defp get_specific_field_type(Ash.Type.DateTime, _, _, _),
    do: Application.get_env(:ash, :utc_datetime_type) || :datetime

  defp get_specific_field_type(Ash.Type.UtcDatetime, _, _, _),
    do: Application.get_env(:ash, :utc_datetime_type) || :datetime

  defp get_specific_field_type(Ash.Type.UtcDatetimeUsec, _, _, _),
    do: Application.get_env(:ash, :utc_datetime_type) || :datetime

  defp get_specific_field_type(Ash.Type.NaiveDatetime, _, _, _), do: :naive_datetime
  defp get_specific_field_type(Ash.Type.Time, _, _, _), do: :time

  defp get_specific_field_type(Ash.Type.UUID, _, _, _), do: :id
  defp get_specific_field_type(Ash.Type.UUIDv7, _, _, _), do: :id
  defp get_specific_field_type(Ash.Type.Float, _, _, _), do: :float

  defp get_specific_field_type(Ash.Type.Struct, %{constraints: constraints}, resource, input?) do
    type =
      if !input? && constraints[:instance_of] &&
           Ash.Resource.Info.resource?(constraints[:instance_of]) do
        AshGraphql.Resource.Info.type(constraints[:instance_of])
      end

    result =
      type || get_specific_field_type(Ash.Type.Map, %{constraints: constraints}, resource, input?)

    # Warn when struct with instance_of falls back to JsonString for input
    if input? && constraints[:instance_of] &&
         Ash.Resource.Info.resource?(constraints[:instance_of]) &&
         result == (Application.get_env(:ash_graphql, :json_type) || :json_string) do
      IO.warn("""
      Struct type with instance_of constraint falls back to JsonString for input. 
      Consider creating a custom type with `use AshGraphql.Type` and `graphql_input_type/1` 
      for structured validation.

      Resource: #{inspect(resource)}
      Target: #{inspect(constraints[:instance_of])}

      See: https://hexdocs.pm/ash_graphql/use-struct-types-with-graphql.html
      """)
    end

    result
  end

  defp get_specific_field_type(Ash.Type.File, _, _, _), do: :upload

  defp get_specific_field_type(type, attribute, resource, _) do
    raise """
    Could not determine graphql field type for #{inspect(type)} on #{inspect(resource)}.#{attribute.name}

    If this is an `Ash.Type.Enum` or a custom type, you can add `def graphql_type/1` or `def graphql_input_type/1`
    to your type. This does not *define* the type, but tells us what type to use for it, so you may need
    to add a type to your absinthe schema if it does not map to a built in absinthe data type.

    ## Ash.Type.NewType

    The exception to the above are special instances of `Ash.Type.NewType`. If you have an `Ash.Type.NewType`,
    that is a subset of `:union` or `:map`(with the `:fields` constraint), AshGraphql will define that type for you.
    If you are seeing this message, it likely means that you are missing `def graphql_type/1` or `def graphql_input_type/1`
    on your type definition.
    """
  end

  def primary_key_get_query(resource, all_domains) do
    # Find the get query with no identities, i.e. the one that uses the primary key
    resource
    |> AshGraphql.Resource.Info.queries(all_domains)
    |> Enum.find(&(&1.type == :get and (&1.identity == nil or &1.identity == false)))
  end

  def embedded?({:array, resource_or_type}) do
    embedded?(resource_or_type)
  end

  def embedded?(resource_or_type) do
    if Ash.Resource.Info.resource?(resource_or_type) do
      Ash.Resource.Info.embedded?(resource_or_type)
    else
      Ash.Type.embedded_type?(resource_or_type)
    end
  end
end
