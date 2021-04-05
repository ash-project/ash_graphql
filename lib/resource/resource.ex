defmodule AshGraphql.Resource do
  alias Ash.Dsl.Extension
  alias Ash.Query.Aggregate
  alias AshGraphql.Resource
  alias AshGraphql.Resource.{Mutation, Query}

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
      @mutations
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

  def type(resource) do
    Extension.get_opt(resource, [:graphql], :type, nil)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:graphql], :primary_key_delimiter, [], false)
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
          type: query_type(query, query_action, type)
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
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: mutation_args(mutation, resource, schema),
          identifier: mutation.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result")
        }

      %{type: :create} = mutation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: [
            %Absinthe.Blueprint.Schema.InputValueDefinition{
              identifier: :input,
              module: schema,
              name: "input",
              placement: :argument_definition,
              type: String.to_atom("#{mutation.name}_input")
            }
          ],
          identifier: mutation.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result")
        }

      mutation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments:
            mutation_args(mutation, resource, schema) ++
              [
                %Absinthe.Blueprint.Schema.InputValueDefinition{
                  identifier: :input,
                  module: schema,
                  name: "input",
                  placement: :argument_definition,
                  type: String.to_atom("#{mutation.name}_input")
                }
              ],
          identifier: mutation.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :mutate}, {api, resource, mutation}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result")
        }
    end)
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
        description: attribute.description || ""
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
        type: :id
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
            type: Resource.type(resource)
          },
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "Any errors generated, if the mutation failed",
            identifier: :errors,
            module: schema,
            name: "errors",
            type: %Absinthe.Blueprint.TypeReference.List{
              of_type: :mutation_error
            }
          }
        ],
        identifier: String.to_atom("#{mutation.name}_result"),
        module: schema,
        name: Macro.camelize("#{mutation.name}_result")
      }

      if mutation.type == :destroy do
        [result]
      else
        input = %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
          fields: mutation_fields(resource, schema, mutation.action, mutation.type),
          identifier: String.to_atom("#{mutation.name}_input"),
          module: schema,
          name: Macro.camelize("#{mutation.name}_input")
        }

        [input, result]
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
      name: Macro.camelize(name)
    }
  end

  defp mutation_fields(resource, schema, action, type) do
    attribute_fields =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.filter(fn attribute ->
        is_nil(action.accept) || attribute.name in action.accept
      end)
      |> Enum.filter(& &1.writable?)
      |> Enum.map(fn attribute ->
        allow_nil? = attribute.allow_nil? || attribute.default || type == :update

        field_type =
          attribute.type
          |> field_type(attribute, resource, true)
          |> maybe_wrap_non_null(not allow_nil?)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type
        }
      end)

    argument_fields =
      action.arguments
      |> Enum.reject(& &1.private?)
      |> Enum.map(fn argument ->
        type =
          argument.type
          |> field_type(argument, resource, true)
          |> maybe_wrap_non_null(not argument.allow_nil?)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: argument.name,
          module: schema,
          name: to_string(argument.name),
          type: type
        }
      end)

    attribute_fields ++ argument_fields
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
        description: "The id of the record"
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
        description: attribute.description || ""
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
              description: "A filter to limit the results"
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
              description: "A filter to limit the results"
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
              description: "How to sort the records in the response"
            }
            | args
          ]
      end

    args ++ pagination_args(action) ++ read_args(resource, action, schema)
  end

  defp read_args(resource, action, schema) do
    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.map(fn argument ->
      type =
        argument.type
        |> field_type(argument, resource, true)
        |> maybe_wrap_non_null(not argument.allow_nil?)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: argument.name,
        module: schema,
        name: to_string(argument.name),
        type: type
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
          description: "The number of records to return." <> max_message
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
          description: "Show records before the specified keyset."
        },
        %Absinthe.Blueprint.Schema.InputValueDefinition{
          name: "after",
          identifier: :after,
          type: :string,
          description: "Show records after the specified keyset."
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
          description: "The number of records to skip."
        }
      ]
    else
      []
    end
  end

  @doc false
  def type_definitions(resource, api, schema) do
    [
      type_definition(resource, api, schema)
    ] ++
      List.wrap(sort_input(resource, schema)) ++
      List.wrap(filter_input(resource, schema)) ++
      filter_field_types(resource, schema) ++
      List.wrap(page_of(resource, schema)) ++ enum_definitions(resource, schema)
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

  defp attribute_or_aggregate_type(%Ash.Resource.Aggregate{kind: kind, field: field}, resource) do
    field_type =
      if field do
        Ash.Resource.Info.attribute(resource, field).type
      end

    {:ok, aggregate_type} = Ash.Query.Aggregate.kind_to_type(kind, field_type)
    aggregate_type
  end

  defp filter_type(attribute_or_aggregate, resource, schema) do
    type = attribute_or_aggregate_type(attribute_or_aggregate, resource)

    fields =
      Enum.flat_map(Ash.Filter.builtin_operators(), fn operator ->
        expressable_types =
          Enum.filter(operator.types(), fn
            [:any, {:array, type}] when is_atom(type) ->
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
              type: field_type(type, attribute_or_aggregate, resource, true)
            }
          ]
        else
          type =
            case Enum.at(expressable_types, 0) do
              [_, {:array, :same}] ->
                {:array, type}

              [_, :same] ->
                type

              [_, :any] ->
                Ash.Type.String

              [_, type] when is_atom(type) ->
                case Ash.Type.get_type(type) do
                  nil ->
                    nil

                  type ->
                    type
                end

              _ ->
                nil
            end

          if type do
            attribute_or_aggregate = constraints_to_item_constraints(type, attribute_or_aggregate)

            [
              %Absinthe.Blueprint.Schema.FieldDefinition{
                identifier: operator.name(),
                module: schema,
                name: to_string(operator.name()),
                type: field_type(type, attribute_or_aggregate, resource, true)
              }
            ]
          else
            []
          end
        end
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
          name: identifier |> to_string() |> Macro.camelize()
        }
      ]
    end
  end

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
              type: :sort_order
            },
            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: :field,
              module: schema,
              name: "field",
              type: resource_sort_field_type(resource)
            }
          ],
          identifier: resource_sort_type(resource),
          module: schema,
          name: resource |> resource_sort_type() |> to_string() |> Macro.camelize()
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
          fields: fields
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
          type: attribute_filter_field_type(resource, attribute)
        }
      ]
    end)
  end

  defp aggregate_filter_fields(resource, schema) do
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.flat_map(fn aggregate ->
      [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: aggregate.name,
          module: schema,
          name: to_string(aggregate.name),
          type: attribute_filter_field_type(resource, aggregate)
        }
      ]
    end)
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
        type: resource_filter_type(relationship.destination)
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
          }
        },
        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: :or,
          module: schema,
          name: "or",
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

  defp enum_definitions(resource, schema) do
    atom_enums =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.filter(&(&1.type == Ash.Type.Atom))
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
          identifier: type_name
        }
      end)

    sort_values = sort_values(resource)

    sort_order = %Absinthe.Blueprint.Schema.EnumTypeDefinition{
      module: schema,
      name: resource |> resource_sort_field_type() |> to_string() |> Macro.camelize(),
      identifier: resource_sort_field_type(resource),
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

  defp sort_values(resource) do
    attribute_sort_values =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.reject(fn
        %{type: {:array, _}} ->
          false

        _ ->
          true
      end)
      |> Enum.reject(&Ash.Type.embedded_type?(&1.type))
      |> Enum.map(& &1.name)

    aggregate_sort_values =
      resource
      |> Ash.Resource.Info.aggregates()
      |> Enum.reject(fn aggregate ->
        case Ash.Query.Aggregate.kind_to_type(aggregate.kind, nil) do
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
            type: :integer
          }
        ],
        identifier: String.to_atom("page_of_#{type}"),
        module: schema,
        name: Macro.camelize("page_of_#{type}")
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
      name: Macro.camelize(to_string(type))
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
          type: field_type
        }
      end)

    pkey_fields =
      case Ash.Resource.Info.primary_key(resource) do
        [field] ->
          attribute = Ash.Resource.Info.attribute(resource, field)

          if attribute.private? do
            non_id_attributes
          else
            field_type =
              attribute.type
              |> field_type(attribute, resource)
              |> maybe_wrap_non_null(not attribute.allow_nil?)

            [
              %Absinthe.Blueprint.Schema.FieldDefinition{
                description: attribute.description,
                identifier: attribute.name,
                module: schema,
                name: to_string(attribute.name),
                type: field_type
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
                  |> maybe_wrap_non_null(not attribute.allow_nil?)

                %Absinthe.Blueprint.Schema.FieldDefinition{
                  description: attribute.description,
                  identifier: attribute.name,
                  module: schema,
                  name: to_string(attribute.name),
                  type: field_type
                }
              end
            end

          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              description: "The primary key of the resource",
              identifier: :id,
              module: schema,
              name: "id",
              type: :id
            }
          ] ++ added_pkey_fields
      end

    non_id_attributes ++ pkey_fields
  end

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
          type: type
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
          arguments: args(:list, relationship.destination, read_action, schema),
          type: query_type
        }
    end)
  end

  defp aggregates(resource, schema) do
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.map(fn aggregate ->
      field_type =
        if aggregate.field do
          Ash.Resource.Info.attribute(resource, aggregate.field).type
        end

      {:ok, type} = Aggregate.kind_to_type(aggregate.kind, field_type)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: aggregate.name,
        module: schema,
        name: to_string(aggregate.name),
        type: field_type(type, nil, resource)
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
        type: field_type
      }
    end)
  end

  defp field_type(type, field, resource, input? \\ false)

  defp field_type({:array, type}, %Ash.Resource.Aggregate{} = aggregate, resource, input?) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type(type, aggregate, resource, input?)
    }
  end

  defp field_type({:array, type}, attribute, resource, input?) do
    new_constraints = attribute.constraints[:items] || []
    new_attribute = %{attribute | constraints: new_constraints, type: type}

    field_type =
      type
      |> field_type(new_attribute, resource, input?)
      |> maybe_wrap_non_null(not attribute.constraints[:nil_items?])

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
        function =
          if input? do
            :graphql_input_type
          else
            :graphql_type
          end

        if is_atom(type) && :erlang.function_exported(type, function, 1) do
          apply(type, function, [attribute.constraints])
        else
          raise """
          Could not determine graphql type for #{type}!
          """
        end
      end
    end
  end

  defp do_field_type(Ash.Type.Atom, %{constraints: constraints, name: name}, resource) do
    if is_list(constraints[:one_of]) do
      atom_enum_type(resource, name)
    else
      :string
    end
  end

  defp do_field_type(Ash.Type.Boolean, _, _), do: :boolean
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
