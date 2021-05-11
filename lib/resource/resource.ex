defmodule AshGraphql.Resource do
  alias Ash.Changeset.ManagedRelationshipHelpers
  alias Ash.Dsl.Extension
  alias Ash.Query.Aggregate
  alias AshGraphql.Resource
  alias AshGraphql.Resource.{ManagedRelationship, Mutation, Query}

  @get %Ash.Dsl.Entity{
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

  @read_one %Ash.Dsl.Entity{
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

  @list %Ash.Dsl.Entity{
    name: :list,
    schema: Query.list_schema(),
    args: [:name, :action],
    describe: "A query to fetch a list of records",
    examples: [
      "list :list_posts, :read"
    ],
    target: Query,
    auto_set_fields: [
      type: :list
    ]
  }

  @create %Ash.Dsl.Entity{
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

  @update %Ash.Dsl.Entity{
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

  @destroy %Ash.Dsl.Entity{
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

  @queries %Ash.Dsl.Section{
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

  @managed_relationship %Ash.Dsl.Entity{
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
        managed_relationship :create_post, :comments
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

  @managed_relationships %Ash.Dsl.Section{
    name: :managed_relationships,
    describe: """
    Generates input objects for `manage_relationship` arguments on reosurce actions.
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

  @mutations %Ash.Dsl.Section{
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

  @graphql %Ash.Dsl.Section{
    name: :graphql,
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
      primary_key_delimiter: [
        type: :string,
        doc:
          "If a composite primary key exists, this must be set to determine the `id` field value"
      ]
    ],
    sections: [
      @queries,
      @mutations,
      @managed_relationships
    ]
  }

  @transformers [
    AshGraphql.Resource.Transformers.RequireIdPkey,
    AshGraphql.Resource.Transformers.ValidateActions
  ]

  @sections [@graphql]

  @moduledoc """
  This Ash resource extension adds configuration for exposing a resource in a graphql.

  # Table of Contents
  #{Ash.Dsl.Extension.doc_index(@sections)}

  #{Ash.Dsl.Extension.doc(@sections)}
  """

  use Extension, sections: @sections, transformers: @transformers

  def queries(resource) do
    Extension.get_entities(resource, [:graphql, :queries])
  end

  def mutations(resource) do
    Extension.get_entities(resource, [:graphql, :mutations]) || []
  end

  def managed_relationships(resource) do
    Extension.get_entities(resource, [:graphql, :managed_relationships]) || []
  end

  def type(resource) do
    Extension.get_opt(resource, [:graphql], :type, nil)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:graphql], :primary_key_delimiter, [], false)
  end

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
      [_field] ->
        {:ok, value}

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
  def queries(api, resource, schema) do
    type = Resource.type(resource)

    if type do
      resource
      |> queries()
      |> Enum.map(fn query ->
        query_action = Ash.Resource.Info.action(resource, query.action, :read)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: args(query.type, resource, query_action, schema, query.identity),
          identifier: query.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, query}}
          ],
          module: schema,
          name: to_string(query.name),
          type: query_type(query, query_action, type),
          __reference__: ref(__ENV__)
        }
      end)
    else
      []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @doc false
  def mutations(api, resource, schema) do
    resource
    |> mutations()
    |> Enum.map(fn
      %{type: :destroy} = mutation ->
        action = Ash.Resource.Info.action(resource, mutation.action)

        if action.soft? do
          update_mutation(resource, schema, mutation, schema, api)
        else
          %Absinthe.Blueprint.Schema.FieldDefinition{
            arguments: mutation_args(mutation, resource, schema),
            identifier: mutation.name,
            middleware: [
              {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
            ],
            module: schema,
            name: to_string(mutation.name),
            type: String.to_atom("#{mutation.name}_result"),
            __reference__: ref(__ENV__)
          }
        end

      %{type: :create} = mutation ->
        action = Ash.Resource.Info.action(resource, mutation.action)

        args =
          case(
            mutation_fields(
              resource,
              schema,
              action,
              mutation.type
            )
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
          middleware: [
            {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result"),
          __reference__: ref(__ENV__)
        }

      mutation ->
        update_mutation(resource, schema, mutation, schema, api)
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp update_mutation(resource, schema, mutation, schema, api) do
    action = Ash.Resource.Info.action(resource, mutation.action)

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
      middleware: [
        {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
      ],
      module: schema,
      name: to_string(mutation.name),
      type: String.to_atom("#{mutation.name}_result"),
      __reference__: ref(__ENV__)
    }
  end

  defp mutation_args(%{identity: false}, _resource, _schema) do
    []
  end

  defp mutation_args(%{identity: identity}, resource, _schema) when not is_nil(identity) do
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
  end

  defp mutation_args(_, _, schema) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        identifier: :id,
        module: schema,
        name: "id",
        placement: :argument_definition,
        type: :id,
        __reference__: ref(__ENV__)
      }
    ]
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def mutation_types(resource, schema) do
    resource
    |> mutations()
    |> Enum.flat_map(fn mutation ->
      mutation = %{
        mutation
        | action: Ash.Resource.Info.action(resource, mutation.action, mutation.type)
      }

      description =
        if mutation.type == :destroy do
          "The record that was successfully deleted"
        else
          "The successful result of the mutation"
        end

      result = %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "The result of the #{inspect(mutation.name)} mutation",
        fields: [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: description,
            identifier: :result,
            module: schema,
            name: "result",
            type: Resource.type(resource),
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
        ],
        identifier: String.to_atom("#{mutation.name}_result"),
        module: schema,
        name: Macro.camelize("#{mutation.name}_result"),
        __reference__: ref(__ENV__)
      }

      if mutation.type == :destroy do
        [result]
      else
        case mutation_fields(
               resource,
               schema,
               mutation.action,
               mutation.type
             ) do
          [] ->
            [result]

          fields ->
            input = %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
              fields: fields,
              identifier: String.to_atom("#{mutation.name}_input"),
              module: schema,
              name: Macro.camelize("#{mutation.name}_input"),
              __reference__: ref(__ENV__)
            }

            [input, result]
        end
      end
    end)
  end

  @doc false
  # sobelow_skip ["DOS.StringToAtom"]
  def embedded_type_input(source_resource, attribute, resource, schema) do
    create_action =
      case attribute.constraints[:create_action] do
        nil ->
          Ash.Resource.Info.primary_action!(resource, :create)

        name ->
          Ash.Resource.Info.action(resource, name, :create)
      end

    update_action =
      case attribute.constraints[:update_action] do
        nil ->
          Ash.Resource.Info.primary_action!(resource, :update)

        name ->
          Ash.Resource.Info.action(resource, name, :update)
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

    name = "#{AshGraphql.Resource.type(source_resource)}_#{attribute.name}_input"

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
        AshGraphql.Resource.managed_relationships(resource),
        &(&1.action == action.name)
      )

    attribute_fields =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.filter(fn attribute ->
        is_nil(action.accept) || attribute.name in action.accept
      end)
      |> Enum.filter(& &1.writable?)
      |> Enum.map(fn attribute ->
        allow_nil? =
          attribute.allow_nil? || attribute.default || type == :update ||
            (type == :create && attribute.name in action.allow_nil_input)

        explicitly_required = attribute.name in action.require_attributes

        field_type =
          attribute.type
          |> field_type(attribute, resource, true)
          |> maybe_wrap_non_null(explicitly_required || attribute_required?(attribute))

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type,
          __reference__: ref(__ENV__)
        }
      end)

    argument_fields =
      action.arguments
      |> Enum.reject(& &1.private?)
      |> Enum.map(fn argument ->
        case find_manage_change(argument, action, managed_relationships) do
          nil ->
            type =
              argument.type
              |> field_type(argument, resource, true)
              |> maybe_wrap_non_null(attribute_required?(argument))

            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: argument.name,
              module: schema,
              name: to_string(argument.name),
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
              name: to_string(argument.name),
              type: maybe_wrap_non_null(type, attribute_required?(argument)),
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
          !constraints[:nil_items?]
        )
    }
  end

  defp wrap_arrays(_, type, _), do: type

  # sobelow_skip ["DOS.StringToAtom"]
  defp default_managed_type_name(resource, action, argument) do
    String.to_atom(
      to_string(action.type) <>
        "_" <>
        to_string(AshGraphql.Resource.type(resource)) <>
        "_" <> to_string(argument.name) <> "_input"
    )
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
  defp query_type(%{type: :list}, action, type) do
    if action.pagination do
      String.to_atom("page_of_#{type}")
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

  defp query_type(query, _action, type) do
    maybe_wrap_non_null(type, not query.allow_nil?)
  end

  defp maybe_wrap_non_null(type, true) do
    %Absinthe.Blueprint.TypeReference.NonNull{
      of_type: type
    }
  end

  defp maybe_wrap_non_null(type, _), do: type

  defp args(action_type, resource, action, schema, identity \\ nil)

  defp args(:get, resource, action, schema, nil) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "id",
        identifier: :id,
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
        description: "The id of the record",
        __reference__: ref(__ENV__)
      }
    ] ++ read_args(resource, action, schema)
  end

  defp args(:get, resource, action, schema, identity) do
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
    |> Enum.concat(read_args(resource, action, schema))
  end

  defp args(:read_one, resource, action, schema, _) do
    args =
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

    args ++ read_args(resource, action, schema)
  end

  defp args(:list, resource, action, schema, _) do
    args =
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

    args =
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

  defp read_args(resource, action, schema) do
    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.map(fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(attribute_required?(argument))

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
        }
      ] ++ keyset_pagination_args(action) ++ offset_pagination_args(action)
    else
      []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp resource_sort_type(resource) do
    String.to_atom(to_string(AshGraphql.Resource.type(resource)) <> "_sort_input")
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp resource_filter_type(resource) do
    String.to_atom(to_string(AshGraphql.Resource.type(resource)) <> "_filter_input")
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp attribute_filter_field_type(resource, attribute) do
    String.to_atom(
      to_string(AshGraphql.Resource.type(resource)) <> "_filter_" <> to_string(attribute.name)
    )
  end

  defp keyset_pagination_args(action) do
    if action.pagination.keyset? do
      [
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
        }
      ]
    else
      []
    end
  end

  defp offset_pagination_args(action) do
    if action.pagination.offset? do
      [
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
    List.wrap(type_definition(resource, api, schema)) ++
      List.wrap(sort_input(resource, schema)) ++
      List.wrap(filter_input(resource, schema)) ++
      filter_field_types(resource, schema) ++
      List.wrap(page_of(resource, schema)) ++
      enum_definitions(resource, schema) ++
      managed_relationship_definitions(resource, schema)
  end

  def no_graphql_types(resource, schema) do
    enum_definitions(resource, schema, true) ++
      managed_relationship_definitions(resource, schema)
  end

  defp managed_relationship_definitions(resource, schema) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.flat_map(fn action ->
      resource
      |> AshGraphql.Resource.managed_relationships()
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
          Ash.OptionsHelpers.set_default!(manage_opts, key, value)
        end)
      else
        Ash.Changeset.manage_relationship_schema()
      end

    manage_opts = Ash.OptionsHelpers.validate!(opts[:opts], manage_opts_schema)

    fields =
      on_match_fields(manage_opts, relationship, schema) ++
        on_no_match_fields(manage_opts, relationship, schema) ++
        on_lookup_fields(manage_opts, relationship, schema) ++
        manage_pkey_fields(manage_opts, managed_relationship, relationship.destination, schema)

    type = managed_relationship.type_name || default_managed_type_name(resource, action, argument)

    fields = check_for_conflicts!(fields, managed_relationship, resource)

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
            type = unwrap_managed_relationship_type(type)
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
          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}'s identity: #{
            identity
          }"

        field ->
          "#{inspect(format_type(field.field.type))} - from #{inspect(field.source.resource)}.#{
            field.source.action
          }"
      end)
      |> Enum.uniq()

    """
    Possible types for #{managed_relationship.action}.#{managed_relationship.argument}.#{name}:

    #{Enum.map(formatted_types, &"  * #{&1}\n")}
    """
  end

  defp unwrap_managed_relationship_type({:non_null, type}) do
    %Absinthe.Blueprint.TypeReference.NonNull{of_type: unwrap_managed_relationship_type(type)}
  end

  defp unwrap_managed_relationship_type({:array, type}) do
    %Absinthe.Blueprint.TypeReference.List{of_type: unwrap_managed_relationship_type(type)}
  end

  defp unwrap_managed_relationship_type(type) do
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
        action = Ash.Resource.Info.action(relationship.through, action)

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

  defp manage_pkey_fields(opts, managed_relationship, resource, schema) do
    if ManagedRelationshipHelpers.could_lookup?(opts) do
      pkey_fields =
        if managed_relationship.lookup_with_primary_key? do
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
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp filter_aggregate_types(resource, schema) do
    resource
    |> Ash.Resource.Info.public_aggregates()
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
      | constraints: [items: constraints, nil_items?: allow_nil?]
    }
  end

  defp constraints_to_item_constraints(_, attribute_or_aggregate), do: attribute_or_aggregate

  defp sort_input(resource, schema) do
    case sort_values(resource) do
      [] ->
        nil

      _ ->
        %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
          fields: [
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
          ],
          identifier: resource_sort_type(resource),
          module: schema,
          name: resource |> resource_sort_type() |> to_string() |> Macro.camelize(),
          __reference__: ref(__ENV__)
        }
    end
  end

  defp filter_input(resource, schema) do
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
  end

  defp resource_filter_fields(resource, schema) do
    boolean_filter_fields(resource, schema) ++
      attribute_filter_fields(resource, schema) ++
      relationship_filter_fields(resource, schema) ++ aggregate_filter_fields(resource, schema)
  end

  defp attribute_filter_fields(resource, schema) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.reject(fn
      {:array, _} ->
        true

      _ ->
        false
    end)
    |> Enum.reject(&Ash.Type.embedded_type?/1)
    |> Enum.flat_map(fn attribute ->
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: attribute_filter_field_type(resource, attribute),
          __reference__: ref(__ENV__)
        }
      ]
    end)
  end

  defp aggregate_filter_fields(resource, schema) do
    if Ash.DataLayer.data_layer_can?(resource, :aggregate_filter) do
      resource
      |> Ash.Resource.Info.public_aggregates()
      |> Enum.flat_map(fn aggregate ->
        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            identifier: aggregate.name,
            module: schema,
            name: to_string(aggregate.name),
            type: attribute_filter_field_type(resource, aggregate),
            __reference__: ref(__ENV__)
          }
        ]
      end)
    else
      []
    end
  end

  defp relationship_filter_fields(resource, schema) do
    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      AshGraphql.Resource.type(relationship.destination)
    end)
    |> Enum.map(fn relationship ->
      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: relationship.name,
        module: schema,
        name: to_string(relationship.name),
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
    type = AshGraphql.Resource.type(resource)
    String.to_atom(to_string(type) <> "_sort_field")
  end

  def enum_definitions(resource, schema, only_auto? \\ false) do
    atom_enums =
      resource
      |> get_auto_enums()
      |> Enum.filter(&is_list(&1.constraints[:one_of]))
      |> Enum.map(fn attribute ->
        type_name = atom_enum_type(resource, attribute.name)

        %Absinthe.Blueprint.Schema.EnumTypeDefinition{
          module: schema,
          name: type_name |> to_string() |> Macro.camelize(),
          values:
            Enum.map(attribute.constraints[:one_of], fn value ->
              %Absinthe.Blueprint.Schema.EnumValueDefinition{
                module: schema,
                identifier: value,
                name: String.upcase(to_string(value)),
                value: value
              }
            end),
          identifier: type_name,
          __reference__: ref(__ENV__)
        }
      end)

    if only_auto? do
      atom_enums
    else
      sort_values = sort_values(resource)

      sort_order = %Absinthe.Blueprint.Schema.EnumTypeDefinition{
        module: schema,
        name: resource |> resource_sort_field_type() |> to_string() |> Macro.camelize(),
        identifier: resource_sort_field_type(resource),
        __reference__: ref(__ENV__),
        values:
          Enum.map(sort_values, fn sort_value ->
            %Absinthe.Blueprint.Schema.EnumValueDefinition{
              module: schema,
              identifier: sort_value,
              name: String.upcase(to_string(sort_value)),
              value: sort_value
            }
          end)
      }

      [sort_order | atom_enums]
    end
  end

  defp get_auto_enums(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.map(fn attribute ->
      unnest(attribute)
    end)
    |> Enum.filter(&(&1.type == Ash.Type.Atom))
  end

  defp unnest(%{type: {:array, type}, constraints: constraints} = attribute) do
    %{attribute | type: type, constraints: constraints[:items] || []}
  end

  defp unnest(other), do: other

  defp sort_values(resource) do
    attribute_sort_values =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(fn
        %{type: {:array, _}} ->
          true

        _ ->
          false
      end)
      |> Enum.reject(&Ash.Type.embedded_type?(&1.type))
      |> Enum.map(& &1.name)

    aggregate_sort_values =
      resource
      |> Ash.Resource.Info.public_aggregates()
      |> Enum.reject(fn aggregate ->
        field_type =
          with field when not is_nil(field) <- aggregate.field,
               related when not is_nil(related) <-
                 Ash.Resource.Info.related(resource, aggregate.relationship_path),
               attr when not is_nil(attr) <- Ash.Resource.Info.attribute(related, aggregate.field) do
            attr.type
          end

        case Ash.Query.Aggregate.kind_to_type(aggregate.kind, field_type) do
          {:ok, {:array, _}} ->
            true

          {:ok, type} ->
            Ash.Type.embedded_type?(type)

          _ ->
            true
        end
      end)
      |> Enum.map(& &1.name)

    attribute_sort_values ++ aggregate_sort_values
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp page_of(resource, schema) do
    type = Resource.type(resource)

    paginatable? =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.any?(fn action ->
        action.type == :read && action.pagination
      end)

    if paginatable? do
      %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        description: "A page of #{inspect(type)}",
        fields: [
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
            description: "The count of records",
            identifier: :count,
            module: schema,
            name: "count",
            type: :integer,
            __reference__: ref(__ENV__)
          }
        ],
        identifier: String.to_atom("page_of_#{type}"),
        module: schema,
        name: Macro.camelize("page_of_#{type}"),
        __reference__: ref(__ENV__)
      }
    else
      nil
    end
  end

  def type_definition(resource, api, schema) do
    type = Resource.type(resource)

    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: Ash.Resource.Info.description(resource),
      fields: fields(resource, api, schema),
      identifier: type,
      module: schema,
      name: Macro.camelize(to_string(type)),
      __reference__: ref(__ENV__)
    }
  end

  defp fields(resource, api, schema) do
    attributes(resource, schema) ++
      relationships(resource, api, schema) ++
      aggregates(resource, schema) ++
      calculations(resource, schema)
  end

  defp attributes(resource, schema) do
    non_id_attributes =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(& &1.primary_key?)
      |> Enum.map(fn attribute ->
        field_type =
          attribute.type
          |> field_type(attribute, resource)
          |> maybe_wrap_non_null(not attribute.allow_nil?)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type,
          __reference__: ref(__ENV__)
        }
      end)

    pkey_fields = pkey_fields(resource, schema)
    non_id_attributes ++ pkey_fields
  end

  defp pkey_fields(resource, schema, require? \\ true) do
    case Ash.Resource.Info.primary_key(resource) do
      [field] ->
        attribute = Ash.Resource.Info.attribute(resource, field)

        if attribute.private? do
          []
        else
          field_type =
            attribute.type
            |> field_type(attribute, resource)
            |> maybe_wrap_non_null(require? && not attribute.allow_nil?)

          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: attribute.description,
              identifier: attribute.name,
              module: schema,
              name: to_string(attribute.name),
              type: field_type,
              __reference__: ref(__ENV__)
            }
          ]
        end

      fields ->
        added_pkey_fields =
          if :id in fields do
            []
          else
            for field <- fields do
              attribute = Ash.Resource.Info.attribute(resource, field)

              field_type =
                attribute.type
                |> field_type(attribute, resource)
                |> maybe_wrap_non_null(require? && not attribute.allow_nil?)

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

        [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "The primary key of the resource",
            identifier: :id,
            module: schema,
            name: "id",
            type: :id,
            __reference__: ref(__ENV__)
          }
        ] ++ added_pkey_fields
    end
  end

  defp attribute_required?(%{allow_nil?: true}), do: false
  defp attribute_required?(%{generated?: true}), do: false
  defp attribute_required?(%{default: default}) when not is_nil(default), do: false
  defp attribute_required?(_), do: true

  # sobelow_skip ["DOS.StringToAtom"]
  defp relationships(resource, api, schema) do
    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      Resource in Ash.Resource.Info.extensions(relationship.destination)
    end)
    |> Enum.map(fn
      %{cardinality: :one} = relationship ->
        type =
          relationship.destination
          |> Resource.type()
          |> maybe_wrap_non_null(relationship.type == :belongs_to && relationship.required?)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(relationship.name),
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc}, {api, relationship}}
          ],
          arguments: [],
          type: type,
          __reference__: ref(__ENV__)
        }

      %{cardinality: :many} = relationship ->
        read_action = Ash.Resource.Info.primary_action!(relationship.destination, :read)

        type = Resource.type(relationship.destination)

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
          name: to_string(relationship.name),
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
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.map(fn aggregate ->
      field_type =
        with field when not is_nil(field) <- aggregate.field,
             related when not is_nil(related) <-
               Ash.Resource.Info.related(resource, aggregate.relationship_path),
             attr when not is_nil(attr) <- Ash.Resource.Info.attribute(related, aggregate.field) do
          attr.type
        end

      {:ok, type} = Aggregate.kind_to_type(aggregate.kind, field_type)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: aggregate.name,
        module: schema,
        name: to_string(aggregate.name),
        type: field_type(type, aggregate, resource),
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp calculations(resource, schema) do
    resource
    |> Ash.Resource.Info.public_calculations()
    |> Enum.map(fn calculation ->
      field_type =
        calculation.type
        |> field_type(nil, resource)
        |> maybe_wrap_non_null(not calculation.allow_nil?)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: calculation.name,
        module: schema,
        name: to_string(calculation.name),
        type: field_type,
        __reference__: ref(__ENV__)
      }
    end)
  end

  defp field_type(type, field, resource, input? \\ false)

  defp field_type(
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
          of_type: field_type(type, aggregate, resource, input?)
        }
      else
        %Absinthe.Blueprint.TypeReference.List{
          of_type: %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: field_type(type, aggregate, resource, input?)
          }
        }
      end
    end
  end

  defp field_type({:array, type}, %Ash.Resource.Aggregate{} = aggregate, resource, input?) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type(type, aggregate, resource, input?)
    }
  end

  defp field_type({:array, type}, nil, resource, input?) do
    field_type = field_type(type, nil, resource, input?)

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  defp field_type({:array, type}, attribute, resource, input?) do
    new_constraints = attribute.constraints[:items] || []
    new_attribute = %{attribute | constraints: new_constraints, type: type}

    field_type =
      type
      |> field_type(new_attribute, resource, input?)
      |> maybe_wrap_non_null(!attribute.constraints[:nil_items?])

    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type
    }
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp field_type(type, attribute, resource, input?) do
    if Ash.Type.builtin?(type) do
      do_field_type(type, attribute, resource)
    else
      if Ash.Type.embedded_type?(type) do
        if input? do
          :"#{AshGraphql.Resource.type(resource)}_#{attribute.name}_input"
        else
          case type(type) do
            nil ->
              :json

            type ->
              type
          end
        end
      else
        if :erlang.function_exported(type, :values, 0) do
          if :erlang.function_exported(type, :graphql_type, 0) do
            type.graphql_type()
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

          if :erlang.function_exported(type, function, 1) do
            apply(type, function, [attribute.constraints])
          else
            raise """
            Could not determine graphql type for #{type}, please define: #{function}/1!
            """
          end
        end
      end
    end
  end

  defp do_field_type(
         Ash.Type.Atom,
         %Ash.Resource.Attribute{constraints: constraints, name: name},
         resource
       ) do
    if is_list(constraints[:one_of]) do
      atom_enum_type(resource, name)
    else
      :string
    end
  end

  defp do_field_type(Ash.Type.Boolean, _, _), do: :boolean
  defp do_field_type(Ash.Type.Atom, _, _), do: :string
  defp do_field_type(Ash.Type.CiString, _, _), do: :string
  defp do_field_type(Ash.Type.Date, _, _), do: :date
  defp do_field_type(Ash.Type.Decimal, _, _), do: :decimal
  defp do_field_type(Ash.Type.Integer, _, _), do: :integer
  defp do_field_type(Ash.Type.Map, _, _), do: :json
  defp do_field_type(Ash.Type.String, _, _), do: :string
  defp do_field_type(Ash.Type.Term, _, _), do: :string
  defp do_field_type(Ash.Type.UtcDatetime, _, _), do: :naive_datetime
  defp do_field_type(Ash.Type.UtcDatetimeUsec, _, _), do: :naive_datetime
  defp do_field_type(Ash.Type.UUID, _, _), do: :string
  defp do_field_type(Ash.Type.Float, _, _), do: :float

  # sobelow_skip ["DOS.StringToAtom"]
  defp atom_enum_type(resource, attribute_name) do
    resource
    |> AshGraphql.Resource.type()
    |> to_string()
    |> Kernel.<>("_")
    |> Kernel.<>(to_string(attribute_name))
    |> String.to_atom()
  end
end
