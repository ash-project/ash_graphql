defmodule AshGraphql.Resource do
  alias Ash.Changeset.ManagedRelationshipHelpers
  alias Ash.Query.Aggregate
  alias AshGraphql.Resource
  alias AshGraphql.Resource.{ManagedRelationship, Mutation, Query}

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
      @list
    ]
  }

  @managed_relationship %Spark.Dsl.Entity{
    name: :managed_relationship,
    schema: ManagedRelationship.schema(),
    args: [:action, :argument],
    target: ManagedRelationship,
    describe: """
    Instructs ash_graphql that a given argument with a `manage_relationship` change should have its input objects derived automatically from the potential actions to be called.

    For example, given an action like:

    ```elixir
    actions do
      create :create do
        argument :comments, {:array, :map}

        change manage_relationship(:comments, type: :direct_control) # <- we look for this change with a matching argument name
      end
    end
    ```

    You could add the following managed_relationship

    ```elixir
    graphql do
      ...

      managed_relationships do
        managed_relationship :create, :comments
      end
    end
    ```

    By default, the `{:array, :map}` would simply be a `json[]` type. If the argument name
    is placed in this list, all of the potential actions that could be called will be combined
    into a single input object. If there are type conflicts (for example, if the input could create
    or update a record, and the create and update actions have an argument of the same name but with a different type),
    a warning is emitted at compile time and the first one is used. If that is insufficient, you will need to do one of the following:

    1.) provide the `:types` option to the `managed_relationship` constructor (see that option for more)
    2.) define a custom type, with a custom input object (see the custom types guide), and use that custom type instead of `:map`
    3.) change your actions to not have overlapping inputs with different types
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
        manage_relationship :create_post, :comments
      end
      """
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
      @destroy
    ]
  }

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
        required: true,
        doc: "The type to use for this entity in the graphql schema"
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
      field_names: [
        type: :keyword_list,
        doc: "A keyword list of name overrides for attributes."
      ],
      argument_names: [
        type: :keyword_list,
        doc:
          "A nested keyword list of action names, to argument name remappings. i.e `create: [arg_name: :new_name]`"
      ],
      keyset_field: [
        type: :atom,
        doc: """
        If set, the keyset will be displayed on all read actions in this field.

        It will always be `nil` unless at least one of the read actions on a resource uses keyset pagination.
        It will also be nil on any mutation results.
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
      primary_key_delimiter: [
        type: :string,
        doc:
          "If a composite primary key exists, this must be set to determine the `id` field value"
      ],
      depth_limit: [
        type: :integer,
        doc: """
        A simple way to prevent massive queries.
        """
      ],
      generate_object?: [
        type: :boolean,
        doc:
          "Whether or not to create the GraphQL object, this allows you to manually create the GraphQL object.",
        default: true
      ]
    ],
    sections: [
      @queries,
      @mutations,
      @managed_relationships
    ]
  }

  @transformers [
    AshGraphql.Resource.Transformers.RequirePkeyDelimiter,
    AshGraphql.Resource.Transformers.RequireKeysetForRelayQueries,
    AshGraphql.Resource.Transformers.ValidateActions,
    AshGraphql.Resource.Transformers.ValidateCompatibleNames,
    AshGraphql.Resource.Transformers.AddUnionTypeResolvers
  ]

  @verifiers [
    AshGraphql.Resource.Verifiers.VerifyQueryMetadata
  ]

  @sections [@graphql]

  @moduledoc """
  This Ash resource extension adds configuration for exposing a resource in a graphql.

  <!--- ash-hq-hide-start --> <!--- -->

  ## DSL Documentation

  ### Index

  #{Spark.Dsl.Extension.doc_index(@sections)}

  ### Docs

  #{Spark.Dsl.Extension.doc(@sections)}
  <!--- ash-hq-hide-stop --> <!--- -->
  """

  use Spark.Dsl.Extension, sections: @sections, transformers: @transformers, verifiers: @verifiers

  @deprecated "See `AshGraphql.Resource.Info.queries/1`"
  defdelegate queries(resource), to: AshGraphql.Resource.Info

  @deprecated "See `AshGraphql.Resource.Info.mutations/1`"
  defdelegate mutations(resource), to: AshGraphql.Resource.Info

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

  @doc false
  def queries(api, resource, action_middleware, schema, as_mutations? \\ false) do
    type = AshGraphql.Resource.Info.type(resource)

    if type do
      resource
      |> queries()
      |> Enum.filter(&(&1.as_mutation? == as_mutations?))
      |> Enum.map(fn query ->
        query_action =
          Ash.Resource.Info.action(resource, query.action) ||
            raise "No such action #{query.action} on #{resource}"

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: args(query.type, resource, query_action, schema, query.identity),
          identifier: query.name,
          middleware:
            action_middleware ++
              [
                {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, query}}
              ],
          complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
          module: schema,
          name: to_string(query.name),
          type: query_type(query, resource, query_action, type),
          __reference__: ref(__ENV__)
        }
      end)
    else
      []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @doc false
  def mutations(api, resource, action_middleware, schema) do
    resource
    |> mutations()
    |> Enum.map(fn
      %{type: :destroy} = mutation ->
        action =
          Ash.Resource.Info.action(resource, mutation.action) ||
            raise "No such action #{mutation.action} for #{inspect(resource)}"

        if action.soft? do
          update_mutation(resource, schema, mutation, schema, action_middleware, api)
        else
          %Absinthe.Blueprint.Schema.FieldDefinition{
            arguments: mutation_args(mutation, resource, schema),
            identifier: mutation.name,
            middleware:
              action_middleware ++
                [
                  {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
                ],
            module: schema,
            name: to_string(mutation.name),
            type: String.to_atom("#{mutation.name}_result"),
            __reference__: ref(__ENV__)
          }
        end

      %{type: :create} = mutation ->
        action =
          Ash.Resource.Info.action(resource, mutation.action) ||
            raise "No such action #{mutation.action} for #{inspect(resource)}"

        args =
          case mutation_fields(
                 resource,
                 schema,
                 action,
                 mutation.type
               ) do
            [] ->
              []

            _ ->
              [
                %Absinthe.Blueprint.Schema.InputValueDefinition{
                  identifier: :input,
                  module: schema,
                  name: "input",
                  placement: :argument_definition,
                  type: String.to_atom("#{mutation.name}_input")
                }
              ]
          end

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: args,
          identifier: mutation.name,
          middleware:
            action_middleware ++
              [
                {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
              ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result"),
          __reference__: ref(__ENV__)
        }

      mutation ->
        update_mutation(resource, schema, mutation, schema, action_middleware, api)
    end)
    |> Enum.concat(queries(api, resource, action_middleware, schema, true))
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp update_mutation(resource, schema, mutation, schema, action_middleware, api) do
    action =
      Ash.Resource.Info.action(resource, mutation.action) ||
        raise "No such action #{mutation.action} for #{inspect(resource)}"

    args =
      case mutation_fields(
             resource,
             schema,
             action,
             mutation.type
           ) do
        [] ->
          mutation_args(mutation, resource, schema)

        _ ->
          mutation_args(mutation, resource, schema) ++
            [
              %Absinthe.Blueprint.Schema.InputValueDefinition{
                identifier: :input,
                module: schema,
                name: "input",
                placement: :argument_definition,
                type: String.to_atom("#{mutation.name}_input"),
                __reference__: ref(__ENV__)
              }
            ]
      end

    %Absinthe.Blueprint.Schema.FieldDefinition{
      arguments: args,
      identifier: mutation.name,
      middleware:
        action_middleware ++
          [
            {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
          ],
      module: schema,
      name: to_string(mutation.name),
      type: String.to_atom("#{mutation.name}_result"),
      __reference__: ref(__ENV__)
    }
  end

  defp mutation_args(%{identity: false} = mutation, resource, schema) do
    mutation_read_args(mutation, resource, schema)
  end

  defp mutation_args(%{identity: identity} = mutation, resource, schema)
       when not is_nil(identity) do
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
          of_type: field_type(attribute.type, attribute, resource)
        },
        description: attribute.description || "",
        __reference__: ref(__ENV__)
      }
    end)
    |> Enum.concat(mutation_read_args(mutation, resource, schema))
  end

  defp mutation_args(mutation, resource, schema) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        identifier: :id,
        module: schema,
        name: "id",
        placement: :argument_definition,
        type: :id,
        __reference__: ref(__ENV__)
      }
      | mutation_read_args(mutation, resource, schema)
    ]
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

    read_action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.map(fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(argument.name),
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def mutation_types(resource, schema) do
    resource
    |> mutations()
    |> Enum.flat_map(fn mutation ->
      mutation = %{
        mutation
        | action:
            Ash.Resource.Info.action(resource, mutation.action) ||
              raise("No such action #{mutation.action} for #{inspect(resource)}")
      }

      description =
        if mutation.type == :destroy do
          "The record that was successfully deleted"
        else
          "The successful result of the mutation"
        end

      fields = [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: description,
          identifier: :result,
          module: schema,
          name: "result",
          type: AshGraphql.Resource.Info.type(resource),
          __reference__: ref(__ENV__)
        },
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: "Any errors generated, if the mutation failed",
          identifier: :errors,
          module: schema,
          name: "errors",
          type: %Absinthe.Blueprint.TypeReference.List{
            of_type: :mutation_error
          },
          __reference__: ref(__ENV__)
        }
      ]

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

      result = %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "The result of the #{inspect(mutation.name)} mutation",
        fields: fields,
        identifier: String.to_atom("#{mutation.name}_result"),
        module: schema,
        name: Macro.camelize("#{mutation.name}_result"),
        __reference__: ref(__ENV__)
      }

      case mutation_fields(
             resource,
             schema,
             mutation.action,
             mutation.type
           ) do
        [] ->
          [result] ++ List.wrap(metadata_object_type)

        fields ->
          input = %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
            fields: fields,
            identifier: String.to_atom("#{mutation.name}_input"),
            module: schema,
            name: Macro.camelize("#{mutation.name}_input"),
            __reference__: ref(__ENV__)
          }

          [input, result] ++ List.wrap(metadata_object_type)
      end
    end)
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

    name = "#{AshGraphql.Resource.Info.type(source_resource)}_#{attribute.name}_input"

    %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
      fields: fields,
      identifier: String.to_atom(name),
      module: schema,
      name: Macro.camelize(name),
      __reference__: ref(__ENV__)
    }
  end

  defp mutation_fields(resource, schema, action, type) do
    managed_relationships =
      Enum.filter(
        AshGraphql.Resource.Info.managed_relationships(resource),
        &(&1.action == action.name)
      )

    field_names = AshGraphql.Resource.Info.field_names(resource)
    argument_names = AshGraphql.Resource.Info.argument_names(resource)

    attribute_fields =
      if action.type == :destroy && !action.soft? do
        []
      else
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.filter(fn attribute ->
          (is_nil(action.accept) || attribute.name in action.accept) && attribute.writable?
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
            description: attribute.description,
            identifier: attribute.name,
            module: schema,
            name: to_string(name),
            type: field_type,
            __reference__: ref(__ENV__)
          }
        end)
      end

    argument_fields =
      action.arguments
      |> Enum.reject(& &1.private?)
      |> Enum.map(fn argument ->
        name = argument_names[action.name][argument.name] || argument.name

        case find_manage_change(argument, action, managed_relationships) do
          nil ->
            type =
              argument.type
              |> field_type(argument, resource, true)
              |> maybe_wrap_non_null(argument_required?(argument))

            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: name,
              module: schema,
              name: to_string(name),
              type: type,
              __reference__: ref(__ENV__)
            }

          _manage_opts ->
            managed = Enum.find(managed_relationships, &(&1.argument == argument.name))

            type =
              if managed.type_name do
                managed.type_name
              else
                default_managed_type_name(resource, action, argument)
              end

            type = wrap_arrays(argument.type, type, argument.constraints)

            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: argument.name,
              module: schema,
              name: to_string(name),
              type: maybe_wrap_non_null(type, argument_required?(argument)),
              __reference__: ref(__ENV__)
            }
        end
      end)

    attribute_fields ++ argument_fields
  end

  defp wrap_arrays({:array, arg_type}, type, constraints) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type:
        maybe_wrap_non_null(
          wrap_arrays(arg_type, type, constraints[:items] || []),
          !constraints[:nil_items?] || Ash.Type.embedded_type?(type)
        )
    }
  end

  defp wrap_arrays(_, type, _), do: type

  type_name_template =
    Application.compile_env(
      :ash_graphql,
      :default_managed_relationship_type_name_template,
      :action_type
    )

  case type_name_template do
    :action_type ->
      # sobelow_skip ["DOS.StringToAtom"]
      defp default_managed_type_name(resource, action, argument) do
        type_name =
          String.to_atom(
            to_string(action.type) <>
              "_" <>
              to_string(AshGraphql.Resource.Info.type(resource)) <>
              "_" <> to_string(argument.name) <> "_input"
          )

        IO.warn("""
        #{inspect(resource)}:

        Type Name Error in `managed_relationship :#{action.name}, #{argument.name}`.

        Type names for managed_relationships have been updated, but for backwards compatibility must
        be explicitly opted into. These type names are better because the old ones are based off of the
        action type, not the action name, and therefore could produce clashes in their type names.

        To resolve this warning, do the following things:

        1) If you want to keep the current type name, set an explicit type name for this and any other
           affected `managed_relationship`. Here is an example of the specific `managed_relationship` with the fix
           applied:

           managed_relationship :#{action.name}, #{argument.name} do
             type_name :#{type_name} # <- add this line
           end

        2) Once you have done the above (or skipped it because you don't care about the type names),
           you can set the following configuration:


           config :ash_graphql, :default_managed_relationship_type_name_template, :action_name
        """)

        type_name
      end

    :action_name ->
      # sobelow_skip ["DOS.StringToAtom"]
      defp default_managed_type_name(_resource, action, argument) do
        String.to_atom(
          to_string(action.name) <>
            "_" <> to_string(argument.name) <> "_input"
        )
      end
  end

  defp find_manage_change(argument, action, managed_relationships) do
    if argument.name in Enum.map(managed_relationships, & &1.argument) do
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

    if action.pagination do
      cond do
        relay? ->
          String.to_atom("#{type}_connection")

        action.pagination.keyset? ->
          String.to_atom("keyset_page_of_#{type}")

        true ->
          String.to_atom("page_of_#{type}")
      end
    else
      %Absinthe.Blueprint.TypeReference.NonNull{
        of_type: %Absinthe.Blueprint.TypeReference.List{
          of_type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: type
          }
        }
      }
    end
  end

  defp query_type(query, _resource, _action, type) do
    type = query.type_name || type

    maybe_wrap_non_null(type, not query.allow_nil?)
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

  defp args(action_type, resource, action, schema, identity \\ nil)

  defp args(:get, resource, action, schema, nil) do
    get_fields(resource) ++
      read_args(resource, action, schema)
  end

  defp args(:get, resource, action, schema, identity) do
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
    |> Enum.concat(read_args(resource, action, schema))
  end

  defp args(:read_one, resource, action, schema, _) do
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

    args ++ read_args(resource, action, schema)
  end

  defp args(:list, resource, action, schema, _) do
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

    args ++ pagination_args(action) ++ read_args(resource, action, schema)
  end

  defp args(:list_related, resource, action, schema, identity) do
    args(:list, resource, action, schema, identity) ++
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

  defp args(:one_related, resource, action, schema, _identity) do
    read_args(resource, action, schema)
  end

  defp read_args(resource, action, schema) do
    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.map(fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(argument_required?(argument))

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(argument.name),
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp pagination_args(action) do
    if action.pagination do
      if action.pagination.keyset? do
        keyset_pagination_args(action)
      else
        offset_pagination_args(action)
      end
    else
      []
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
  def type_definitions(resource, api, schema) do
    List.wrap(calculation_input(resource, schema)) ++
      List.wrap(type_definition(resource, api, schema)) ++
      List.wrap(query_type_definitions(resource, api, schema)) ++
      List.wrap(sort_input(resource, schema)) ++
      List.wrap(filter_input(resource, schema)) ++
      filter_field_types(resource, schema) ++
      List.wrap(page_of(resource, schema)) ++
      List.wrap(relay_page(resource, schema)) ++
      List.wrap(keyset_page_of(resource, schema)) ++
      enum_definitions(resource, schema, __ENV__) ++
      union_definitions(resource, schema, __ENV__) ++
      managed_relationship_definitions(resource, schema)
  end

  def no_graphql_types(resource, schema) do
    enum_definitions(resource, schema, __ENV__, true) ++
      union_definitions(resource, schema, __ENV__) ++
      managed_relationship_definitions(resource, schema)
  end

  defp managed_relationship_definitions(resource, schema) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.flat_map(fn action ->
      resource
      |> AshGraphql.Resource.Info.managed_relationships()
      |> Enum.filter(&(&1.action == action.name))
      |> Enum.map(fn managed_relationship ->
        argument =
          Enum.find(action.arguments, &(&1.name == managed_relationship.argument)) ||
            raise """
            No such argument #{managed_relationship.argument}, in `managed_relationship`
            """

        opts =
          find_manage_change(argument, action, [managed_relationship]) ||
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
          Spark.OptionsHelpers.set_default!(manage_opts, key, value)
        end)
      else
        Ash.Changeset.manage_relationship_schema()
      end

    manage_opts = Spark.OptionsHelpers.validate!(opts[:opts], manage_opts_schema)

    fields =
      on_match_fields(manage_opts, relationship, schema) ++
        on_no_match_fields(manage_opts, relationship, schema) ++
        on_lookup_fields(manage_opts, relationship, schema) ++
        manage_pkey_fields(manage_opts, managed_relationship, relationship, schema)

    type = managed_relationship.type_name || default_managed_type_name(resource, action, argument)

    fields = check_for_conflicts!(fields, managed_relationship, resource)

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
    raise """
    #{inspect(resource)}: #{managed_relationship.action}.#{managed_relationship.argument}

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
          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}.#{field.source.action}"
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
        []

      {:destination, action} ->
        action = Ash.Resource.Info.action(relationship.destination, action)

        relationship.destination
        |> mutation_fields(schema, action, action.type)
        |> Enum.map(fn field ->
          {relationship.destination, action.name, field}
        end)

      {:source, nil} ->
        []

      {:source, action} ->
        action = Ash.Resource.Info.action(relationship.source, action)

        relationship.source
        |> mutation_fields(schema, action, action.type)
        |> Enum.map(fn field ->
          {relationship.source, action.name, field}
        end)

      {:join, nil, _} ->
        []

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

      nil ->
        []
    end
  end

  defp on_match_fields(opts, relationship, schema) do
    opts
    |> ManagedRelationshipHelpers.on_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.flat_map(fn
      {:destination, nil} ->
        []

      {:destination, action_name} ->
        action = Ash.Resource.Info.action(relationship.destination, action_name)

        relationship.destination
        |> mutation_fields(schema, action, action.type)
        |> Enum.map(fn field ->
          {relationship.destination, action.name, field}
        end)

      {:join, nil, _} ->
        []

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
    end)
  end

  defp on_no_match_fields(opts, relationship, schema) do
    opts
    |> ManagedRelationshipHelpers.on_no_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.flat_map(fn
      {:destination, nil} ->
        []

      {:destination, action_name} ->
        action = Ash.Resource.Info.action(relationship.destination, action_name)

        relationship.destination
        |> mutation_fields(schema, action, action.type)
        |> Enum.map(fn field ->
          {relationship.destination, action.name, field}
        end)

      {:join, nil, _} ->
        []

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
    end)
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
        is_nil(managed_relationship.lookup_identities) ||
          identity.name in managed_relationship.lookup_identities
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
      []
    end
  end

  defp filter_field_types(resource, schema) do
    filter_attribute_types(resource, schema) ++ filter_aggregate_types(resource, schema)
  end

  defp filter_attribute_types(resource, schema) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&filterable?(&1, resource))
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp filter_aggregate_types(resource, schema) do
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.filter(&filterable?(&1, resource))
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
           attr when not is_nil(attr) <- Ash.Resource.Info.attribute(related, field) do
        attr.type
      end

    {:ok, aggregate_type} = Ash.Query.Aggregate.kind_to_type(kind, field_type)

    aggregate_type
  end

  defp filter_type(attribute_or_aggregate, resource, schema) do
    type = attribute_or_aggregate_type(attribute_or_aggregate, resource)

    array_type? = match?({:array, _}, type)

    fields =
      Ash.Filter.builtin_operators()
      |> Enum.filter(& &1.predicate?)
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

  defp filter_fields(operator, type, array_type?, schema, attribute_or_aggregate, resource) do
    expressable_types =
      Enum.filter(operator.types(), fn
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

        _ ->
          false
      end)

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

        if Ash.Type.embedded_type?(type) do
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
    _ ->
      []
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
          nil_items?: allow_nil? || Ash.Type.embedded_type?(attribute.type)
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
      |> Enum.reject(fn
        %{type: {:array, _}} ->
          true

        calc ->
          Ash.Type.embedded_type?(calc.type) || Enum.empty?(calc.arguments)
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
  defp calculation_input(resource, schema) do
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
        |> Enum.filter(& &1.predicate?)
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

  defp attribute_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&filterable?(&1, resource))
    |> Enum.flat_map(fn attribute ->
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: attribute.name,
          module: schema,
          name: to_string(field_names[attribute.name] || attribute.name),
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
      |> Enum.filter(&filterable?(&1, resource))
      |> Enum.flat_map(fn aggregate ->
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            identifier: aggregate.name,
            module: schema,
            name: to_string(field_names[aggregate.name] || aggregate.name),
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
      |> Enum.filter(&filterable?(&1, resource))
      |> Enum.map(fn calculation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: calculation.name,
          module: schema,
          name: to_string(field_names[calculation.name] || calculation.name),
          type: calculation_filter_field_type(resource, calculation),
          __reference__: ref(__ENV__)
        }
      end)
    else
      []
    end
  end

  defp filterable?(%Ash.Resource.Aggregate{} = aggregate, resource) do
    field_type =
      with field when not is_nil(field) <- aggregate.field,
           related when not is_nil(related) <-
             Ash.Resource.Info.related(resource, aggregate.relationship_path),
           attr when not is_nil(attr) <- Ash.Resource.Info.attribute(related, aggregate.field) do
        attr.type
      end

    {:ok, type} = Aggregate.kind_to_type(aggregate.kind, field_type)

    filterable?(%Ash.Resource.Attribute{name: aggregate.name, type: type}, resource)
  end

  defp filterable?(%{type: {:array, _}}, _), do: false
  defp filterable?(%{filterable?: false}, _), do: false
  defp filterable?(%{type: Ash.Type.Union}, _), do: false

  defp filterable?(%Ash.Resource.Calculation{type: type, calculation: {module, _opts}}, _) do
    !Ash.Type.embedded_type?(type) && function_exported?(module, :expression, 2)
  end

  defp filterable?(%{type: type}, _) do
    !Ash.Type.embedded_type?(type)
  end

  defp filterable?(_, _), do: false

  defp relationship_filter_fields(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    relationships = AshGraphql.Resource.Info.relationships(resource)

    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      Resource in Spark.extensions(relationship.destination) && relationship.name in relationships
    end)
    |> Enum.map(fn relationship ->
      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: relationship.name,
        module: schema,
        name: to_string(field_names[relationship.name] || relationship.name),
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

  def enum_definitions(resource, schema, env, only_auto? \\ false) do
    resource = Ash.Type.NewType.subtype_of(resource)

    if AshGraphql.Resource.Info.type(resource) do
      atom_enums =
        resource
        |> get_auto_enums()
        |> Enum.flat_map(fn attribute ->
          constraints = Ash.Type.NewType.constraints(attribute.type, attribute.constraints)

          type_name =
            if constraints[:one_of] do
              if Ash.Type.NewType.new_type?(attribute.type) do
                cond do
                  function_exported?(attribute.type, :graphql_type, 0) ->
                    attribute.type.graphql_type()

                  function_exported?(attribute.type, :graphql_type, 1) ->
                    attribute.type.graphql_type(attribute.constraints)

                  true ->
                    atom_enum_type(resource, attribute.name)
                end
              else
                atom_enum_type(resource, attribute.name)
              end
            end

          additional_type_name =
            if constraints[:one_of] && Ash.Type.NewType.new_type?(attribute.type) do
              cond do
                function_exported?(attribute.type, :graphql_input_type, 0) ->
                  attribute.type.graphql_input_type()

                function_exported?(attribute.type, :graphql_input_type, 1) ->
                  attribute.type.graphql_input_type(attribute.constraints)

                true ->
                  atom_enum_type(resource, attribute.name)
              end
            else
              nil
            end

          [
            type_name,
            additional_type_name
          ]
          |> Enum.filter(& &1)
          |> Enum.map(fn type_name ->
            %Absinthe.Blueprint.Schema.EnumTypeDefinition{
              module: schema,
              name: type_name |> to_string() |> Macro.camelize(),
              values:
                Enum.map(constraints[:one_of], fn value ->
                  %Absinthe.Blueprint.Schema.EnumValueDefinition{
                    module: schema,
                    identifier: value,
                    __reference__: AshGraphql.Resource.ref(env),
                    name: String.upcase(to_string(value)),
                    value: value
                  }
                end),
              identifier: type_name,
              __reference__: ref(__ENV__)
            }
          end)
        end)

      if only_auto? || !AshGraphql.Resource.Info.derive_sort?(resource) do
        atom_enums
      else
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

        [sort_order | atom_enums]
      end
    else
      []
    end
  end

  # sobelow_skip ["RCE.CodeModule", "DOS.BinToAtom", "DOS.StringToAtom"]
  def union_definitions(resource, schema, env) do
    if AshGraphql.Resource.Info.type(resource) do
      resource
      |> get_auto_unions()
      |> Enum.flat_map(fn attribute ->
        type_name =
          if Ash.Type.NewType.new_type?(attribute.type) do
            cond do
              function_exported?(attribute.type, :graphql_type, 0) ->
                attribute.type.graphql_type()

              function_exported?(attribute.type, :graphql_type, 1) ->
                attribute.type.graphql_type(attribute.constraints)

              true ->
                atom_enum_type(resource, attribute.name)
            end
          else
            atom_enum_type(resource, attribute.name)
          end

        input_type_name =
          if Ash.Type.NewType.new_type?(attribute.type) do
            cond do
              function_exported?(attribute.name, :graphql_input_type, 0) ->
                attribute.type.graphql_input_type()

              function_exported?(attribute.name, :graphql_input_type, 1) ->
                attribute.type.graphql_input_type(attribute.constraints)

              true ->
                "#{atom_enum_type(resource, attribute.name)}_input"
            end
          else
            "#{atom_enum_type(resource, attribute.name)}_input"
          end

        constraints = Ash.Type.NewType.constraints(attribute.type, attribute.constraints)

        names_to_field_types =
          Map.new(constraints[:types] || %{}, fn {name, config} ->
            {name,
             field_type(
               config[:type],
               %{attribute | name: String.to_atom("#{attribute.name}_#{name}")},
               resource
             )}
          end)

        func_name = :"resolve_gql_union_#{type_name}"

        {func, _} =
          Code.eval_quoted(
            {:&, [],
             [
               {:/, [],
                [
                  {{:., [], [resource, func_name]}, [], []},
                  2
                ]}
             ]},
            []
          )

        constraints = Ash.Type.NewType.constraints(attribute.type, attribute.constraints)

        [
          %Absinthe.Blueprint.Schema.UnionTypeDefinition{
            module: schema,
            name: type_name |> to_string() |> Macro.camelize(),
            resolve_type: func,
            types:
              Enum.map(constraints[:types], fn {name, _} ->
                %Absinthe.Blueprint.TypeReference.Name{
                  name: "#{type_name}_#{name}" |> Macro.camelize()
                }
              end),
            identifier: type_name,
            __reference__: ref(env)
          },
          %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
            module: schema,
            name: input_type_name |> to_string() |> Macro.camelize(),
            identifier: String.to_atom(input_type_name),
            __reference__: ref(env),
            fields:
              Enum.map(constraints[:types], fn {name, config} ->
                %Absinthe.Blueprint.Schema.InputValueDefinition{
                  name: name |> to_string(),
                  identifier: name,
                  __reference__: ref(env),
                  type:
                    field_type(
                      config[:type],
                      %{attribute | name: String.to_atom("#{attribute.name}_#{name}")},
                      resource,
                      true
                    )
                }
              end)
          }
        ] ++
          Enum.map(constraints[:types], fn {name, _} ->
            %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
              module: schema,
              name: "#{type_name}_#{name}" |> Macro.camelize(),
              identifier: :"#{type_name}_#{name}",
              __reference__: ref(env),
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
      end)
    else
      []
    end
  end

  @doc false
  def get_auto_enums(resource) do
    resource
    |> AshGraphql.all_attributes_and_arguments([], false)
    |> Enum.map(&unnest/1)
    |> Enum.filter(&(Ash.Type.NewType.subtype_of(&1.type) == Ash.Type.Atom))
    |> Enum.uniq_by(& &1.name)
  end

  defp unnest(%{type: {:array, type}, constraints: constraints} = attribute) do
    %{attribute | type: type, constraints: constraints[:items] || []}
  end

  defp unnest(other), do: other

  @doc false
  def get_auto_unions(resource) do
    resource
    |> AshGraphql.all_attributes_and_arguments()
    |> Enum.map(fn attribute ->
      unnest(attribute)
    end)
    |> Enum.filter(&(Ash.Type.NewType.subtype_of(&1.type) == Ash.Type.Union))
  end

  defp sort_values(resource) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(Ash.Resource.Info.public_calculations(resource))
    |> Enum.concat(Ash.Resource.Info.public_aggregates(resource))
    |> Enum.filter(&filterable?(&1, resource))
    |> Enum.map(& &1.name)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      {field_names[name] || name, name}
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp relay_page(resource, schema) do
    type = AshGraphql.Resource.Info.type(resource)

    paginatable? =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.any?(fn action ->
        action.type == :read && action.pagination
      end)

    if paginatable? do
      relay? =
        resource
        |> queries()
        |> Enum.any?(& &1.relay?)

      countable? =
        resource
        |> queries()
        |> Enum.any?(fn query ->
          action = Ash.Resource.Info.action(resource, query.action)
          query.relay? && action.pagination && action.pagination.countable
        end)

      if relay? do
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
                type: type
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
                    of_type: String.to_atom("#{type}_edge")
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
    end
  end

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
  defp page_of(resource, schema) do
    type = AshGraphql.Resource.Info.type(resource)

    paginatable? =
      resource
      |> queries()
      |> Enum.any?(fn query ->
        action = Ash.Resource.Info.action(resource, query.action)
        action.type == :read && action.pagination
      end)

    countable? =
      resource
      |> queries()
      |> Enum.any?(fn query ->
        action = Ash.Resource.Info.action(resource, query.action)
        action.pagination && action.pagination.offset? && action.pagination.countable
      end)

    if paginatable? do
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
            },
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: "Wether or not there is a next page",
              identifier: :more?,
              module: schema,
              name: "has_next_page",
              __reference__: ref(__ENV__),
              type: %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: :boolean
              }
            }
          ]
          |> add_count_to_page(schema, countable?),
        identifier: String.to_atom("page_of_#{type}"),
        module: schema,
        name: Macro.camelize("page_of_#{type}"),
        __reference__: ref(__ENV__)
      }
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp keyset_page_of(resource, schema) do
    type = AshGraphql.Resource.Info.type(resource)

    paginatable? =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.any?(fn action ->
        action.type == :read && action.pagination
      end)

    countable? =
      resource
      |> queries()
      |> Enum.any?(fn query ->
        action = Ash.Resource.Info.action(resource, query.action)
        action.pagination && action.pagination.keyset? && action.pagination.countable
      end)

    if paginatable? do
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
  end

  def is_node_type(type) do
    type.identifier == :node
  end

  def query_type_definitions(resource, api, schema) do
    resource_type = AshGraphql.Resource.Info.type(resource)

    resource
    |> AshGraphql.Resource.Info.queries()
    |> Enum.filter(&(&1.type_name && &1.type_name != resource_type))
    |> Enum.map(fn query ->
      relay? = Map.get(query, :relay?)

      interfaces =
        if relay? do
          [:node]
        else
          []
        end

      is_type_of =
        if relay? do
          &AshGraphql.Resource.is_node_type/1
        else
          nil
        end

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: Ash.Resource.Info.description(resource),
        interfaces: interfaces,
        fields: fields(resource, api, schema, query),
        identifier: query.type_name,
        module: schema,
        name: Macro.camelize(to_string(query.type_name)),
        __reference__: ref(__ENV__),
        is_type_of: is_type_of
      }
    end)
  end

  def type_definition(resource, api, schema) do
    actual_resource = Ash.Type.NewType.subtype_of(resource)

    if generate_object?(resource) do
      type = AshGraphql.Resource.Info.type(resource)

      resource = actual_resource

      relay? =
        resource
        |> queries()
        |> Enum.any?(& &1.relay?)

      interfaces =
        if relay? do
          [:node]
        else
          []
        end

      is_type_of =
        if relay? do
          &AshGraphql.Resource.is_node_type/1
        else
          nil
        end

      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: Ash.Resource.Info.description(resource),
        interfaces: interfaces,
        fields: fields(resource, api, schema),
        identifier: type,
        module: schema,
        name: Macro.camelize(to_string(type)),
        __reference__: ref(__ENV__),
        is_type_of: is_type_of
      }
    end
  end

  defp fields(resource, api, schema, query \\ nil) do
    attributes(resource, schema) ++
      metadata(query, resource, schema) ++
      relationships(resource, api, schema) ++
      aggregates(resource, schema) ++
      calculations(resource, api, schema) ++
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

  defp attributes(resource, schema) do
    attribute_names = AshGraphql.Resource.Info.field_names(resource)

    attributes =
      if AshGraphql.Resource.Info.encode_primary_key?(resource) do
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.reject(& &1.primary_key?)
      else
        Ash.Resource.Info.public_attributes(resource)
      end

    attributes =
      attributes
      |> Enum.map(fn attribute ->
        field_type =
          attribute.type
          |> field_type(attribute, resource)
          |> maybe_wrap_non_null(not attribute.allow_nil?)

        name = attribute_names[attribute.name] || attribute.name

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(name),
          type: field_type,
          __reference__: ref(__ENV__)
        }
      end)

    if AshGraphql.Resource.Info.encode_primary_key?(resource) do
      encoded_primary_key_attributes(resource, schema) ++
        attributes
    else
      attributes
    end
  end

  defp encoded_primary_key_attributes(resource, schema) do
    case Ash.Resource.Info.primary_key(resource) do
      [field] ->
        attribute = Ash.Resource.Info.attribute(resource, field)

        if attribute.private? do
          []
        else
          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: attribute.description,
              identifier: :id,
              module: schema,
              name: "id",
              type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
              middleware: [
                {{AshGraphql.Graphql.Resolver, :resolve_id}, {resource, field}}
              ],
              __reference__: ref(__ENV__)
            }
          ]
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
              {{AshGraphql.Graphql.Resolver, :resolve_composite_id}, {resource, fields}}
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
  defp relationships(resource, api, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    relationships = AshGraphql.Resource.Info.relationships(resource)

    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      Resource in Spark.extensions(relationship.destination) && relationship.name in relationships &&
        AshGraphql.Resource.Info.type(relationship.destination)
    end)
    |> Enum.map(fn
      %{cardinality: :one} = relationship ->
        name = field_names[relationship.name] || relationship.name

        type =
          relationship.destination
          |> AshGraphql.Resource.Info.type()
          |> maybe_wrap_non_null(!relationship.allow_nil?)

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
          arguments: args(:one_related, relationship.destination, read_action, schema),
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc}, {api, relationship}}
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

        query_type = %Absinthe.Blueprint.TypeReference.NonNull{
          of_type: %Absinthe.Blueprint.TypeReference.List{
            of_type: %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: type
            }
          }
        }

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(name),
          complexity: {AshGraphql.Graphql.Resolver, :query_complexity},
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc}, {api, relationship}}
          ],
          arguments: args(:list_related, relationship.destination, read_action, schema),
          type: query_type,
          __reference__: ref(__ENV__)
        }
    end)
  end

  defp aggregates(resource, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.map(fn aggregate ->
      name = field_names[aggregate.name] || aggregate.name

      field_type =
        with field when not is_nil(field) <- aggregate.field,
             related when not is_nil(related) <-
               Ash.Resource.Info.related(resource, aggregate.relationship_path),
             attr when not is_nil(attr) <- Ash.Resource.Info.attribute(related, aggregate.field) do
          attr.type
        end

      {:ok, type} = Aggregate.kind_to_type(aggregate.kind, field_type)

      type =
        if is_nil(Ash.Query.Aggregate.default_value(aggregate.kind)) do
          field_type(type, aggregate, resource)
        else
          %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: field_type(type, aggregate, resource)
          }
        end

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: aggregate.name,
        module: schema,
        name: to_string(name),
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp calculations(resource, api, schema) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> Ash.Resource.Info.public_calculations()
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
          {{AshGraphql.Graphql.Resolver, :resolve_calculation}, {api, resource, calculation}}
        ],
        name: to_string(name),
        type: field_type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp calculation_type(calculation, resource) do
    calculation.type
    |> Ash.Type.get_type()
    |> field_type(calculation, resource)
    |> maybe_wrap_non_null(not calculation.allow_nil?)
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
        type: type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  def field_type(type, field, resource, input? \\ false) do
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
          do_field_type(type, field, resource, input?)
        end

      _ ->
        do_field_type(type, field, resource, input?)
    end
  end

  defp do_field_type(type, field, resource, input?)

  defp do_field_type(
         {:array, type},
         %Ash.Resource.Aggregate{kind: :list} = aggregate,
         resource,
         input?
       ) do
    with related when not is_nil(related) <-
           Ash.Resource.Info.related(resource, aggregate.relationship_path),
         attr when not is_nil(related) <- Ash.Resource.Info.attribute(related, aggregate.field) do
      if attr.allow_nil? do
        %Absinthe.Blueprint.TypeReference.List{
          of_type: do_field_type(type, aggregate, resource, input?)
        }
      else
        %Absinthe.Blueprint.TypeReference.List{
          of_type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: do_field_type(type, aggregate, resource, input?)
          }
        }
      end
    end
  end

  defp do_field_type({:array, type}, %Ash.Resource.Aggregate{} = aggregate, resource, input?) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: do_field_type(type, aggregate, resource, input?)
    }
  end

  defp do_field_type({:array, type}, nil, resource, input?) do
    field_type = do_field_type(type, nil, resource, input?)

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  defp do_field_type({:array, type}, attribute, resource, input?) do
    new_constraints = attribute.constraints[:items] || []
    new_attribute = %{attribute | constraints: new_constraints, type: type}

    field_type =
      type
      |> do_field_type(new_attribute, resource, input?)
      |> maybe_wrap_non_null(
        !attribute.constraints[:nil_items?] || Ash.Type.embedded_type?(attribute.type)
      )

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp do_field_type(type, attribute, resource, input?) do
    type = Ash.Type.get_type(type)

    if Ash.Type.builtin?(type) do
      get_specific_field_type(type, attribute, resource, input?)
    else
      if Spark.Dsl.is?(type, Ash.Resource) && !Ash.Type.embedded_type?(type) do
        if input? do
          raise "Cannot construct an input type for #{inspect(type)}"
        end

        AshGraphql.Resource.Info.type(type)
      else
        if Ash.Type.embedded_type?(type) do
          if input? && type(type) do
            :"#{AshGraphql.Resource.Info.type(resource)}_#{attribute.name}_input"
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
            cond do
              function_exported?(type, :graphql_type, 0) ->
                type.graphql_type()

              function_exported?(type, :graphql_type, 1) ->
                type.graphql_type(attribute.constraints)

              true ->
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
                apply(type, function, [Map.get(attribute, :constraints)])

              function_exported?(type, function, 0) ->
                apply(type, function, [])

              true ->
                if Ash.Type.NewType.new_type?(type) do
                  do_field_type(
                    type.subtype_of(),
                    %{
                      attribute
                      | type: type.subtype_of(),
                        constraints:
                          type.type_constraints(
                            attribute.constraints,
                            type.subtype_constraints()
                          )
                    },
                    resource,
                    input?
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
         %Ash.Resource.Attribute{constraints: constraints, name: name},
         resource,
         _input?
       )
       when not is_nil(resource) do
    if is_list(constraints[:one_of]) do
      atom_enum_type(resource, name)
    else
      :string
    end
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp get_specific_field_type(
         Ash.Type.Union,
         %Ash.Resource.Attribute{name: name},
         resource,
         input?
       )
       when not is_nil(resource) do
    # same logic for naming a union currently
    base_type_name = atom_enum_type(resource, name)

    if input? do
      :"#{base_type_name}_input"
    else
      base_type_name
    end
  end

  defp get_specific_field_type(Ash.Type.Boolean, _, _, _), do: :boolean

  defp get_specific_field_type(Ash.Type.Atom, _, _, _) do
    :string
  end

  defp get_specific_field_type(Ash.Type.CiString, _, _, _), do: :string
  defp get_specific_field_type(Ash.Type.Date, _, _, _), do: :date
  defp get_specific_field_type(Ash.Type.Decimal, _, _, _), do: :decimal
  defp get_specific_field_type(Ash.Type.Integer, _, _, _), do: :integer
  defp get_specific_field_type(Ash.Type.DurationName, _, _, _), do: :duration_name

  defp get_specific_field_type(Ash.Type.Map, _, _, _),
    do: Application.get_env(:ash_graphql, :json_type) || :json_string

  defp get_specific_field_type(Ash.Type.String, _, _, _), do: :string
  defp get_specific_field_type(Ash.Type.Term, _, _, _), do: :string

  defp get_specific_field_type(Ash.Type.UtcDatetime, _, _, _),
    do: Application.get_env(:ash, :utc_datetime_type) || raise_datetime_error()

  defp get_specific_field_type(Ash.Type.UtcDatetimeUsec, _, _, _),
    do: Application.get_env(:ash, :utc_datetime_type) || raise_datetime_error()

  defp get_specific_field_type(Ash.Type.NaiveDatetime, _, _, _), do: :naive_datetime
  defp get_specific_field_type(Ash.Type.Time, _, _, _), do: :time

  defp get_specific_field_type(Ash.Type.UUID, _, _, _), do: :id
  defp get_specific_field_type(Ash.Type.Float, _, _, _), do: :float

  defp get_specific_field_type(type, attribute, resource, _) do
    raise """
    Could not determine graphql field type for #{inspect(type)} on #{inspect(resource)}.#{attribute.name}

    If this is a custom type, you can add `def graphql_type/1` to your type to define the graphql type.
    If this is not your type, you will need to use `types` or `attribute_types` or `attribute_input_types`
    to configure the type for any field using this type. If this is an `Ash.Type.NewType`, you may need to define
    `graphql_type` and `graphql_input_type`s for it.
    """
  end

  defp raise_datetime_error do
    raise """
    No type configured for utc_datetimes!

    The existing default of using `:naive_datetime` for `:utc_datetime` and `:utc_datetime_usec` is being deprecated.

    To prevent accidental API breakages, we are requiring that you configure your selected type for these, via

        # This was the previous default, so use this if you want to ensure no unintended
        # change in your API, although switching to `:datetime` eventually is suggested.
        config :ash, :utc_datetime_type, :naive_datetime

        or

        config :ash, :utc_datetime_type, :datetime

    When the 1.0 version of ash_graphql is released, the default will be changed to `:datetime`, and this error message will
    no longer be shown (but any configuration set will be retained indefinitely).
    """
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @doc false
  def atom_enum_type(resource, attribute_name) do
    field_names = AshGraphql.Resource.Info.field_names(resource)

    resource
    |> AshGraphql.Resource.Info.type()
    |> to_string()
    |> Kernel.<>("_")
    |> Kernel.<>(to_string(field_names[attribute_name] || attribute_name))
    |> String.to_atom()
  end
end
