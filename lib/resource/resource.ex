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
      "get :get_post, :default"
    ],
    schema: Query.get_schema(),
    target: Query,
    auto_set_fields: [
      type: :get
    ]
  }

  @list %Ash.Dsl.Entity{
    name: :list,
    schema: Query.list_schema(),
    args: [:name, :action],
    describe: "A query to fetch a list of records",
    examples: [
      "list :list_posts, :default"
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
      "create :create_post, :default"
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
      "update :update_post, :default"
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
      "destroy :destroy_post, :default"
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
        get :get_post, :default
        list :list_posts, :default
      end
      """
    ],
    entities: [
      @get,
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
        create :create_post, :default
        update :update_post, :default
        destroy :destroy_post, :default
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
          get :get_post, :default
          list :list_posts, :default
        end

        mutations do
          create :create_post, :default
          update :update_post, :default
          destroy :destroy_post, :default
        end
      end
      """
    ],
    schema: [
      type: [
        type: :atom,
        required: true,
        doc: "The type to use for this entity in the graphql schema"
      ]
    ],
    sections: [
      @queries,
      @mutations
    ]
  }

  @transformers [
    AshGraphql.Resource.Transformers.RequireIdPkey
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
    Extension.get_entities(resource, [:graphql, :mutations])
  end

  def type(resource) do
    Extension.get_opt(resource, [:graphql], :type, nil)
  end

  @doc false
  def queries(api, resource, schema) do
    type = Resource.type(resource)

    if type do
      resource
      |> queries()
      |> Enum.map(fn query ->
        query_action = Ash.Resource.action(resource, query.action, :read)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: args(query.type, resource, query_action, query.identity),
          identifier: query.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, query}}
          ],
          module: schema,
          name: to_string(query.name),
          type: query_type(query.type, query_action, type)
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
    |> Ash.Resource.identities()
    |> Enum.find(&(&1.name == identity))
    |> Map.get(:keys)
    |> Enum.map(fn key ->
      attribute = Ash.Resource.attribute(resource, key)

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
        | action: Ash.Resource.action(resource, mutation.action, mutation.type)
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
          fields: mutation_fields(resource, schema, mutation),
          identifier: String.to_atom("#{mutation.name}_input"),
          module: schema,
          name: Macro.camelize("#{mutation.name}_input")
        }

        [input, result]
      end
    end)
  end

  defp mutation_fields(resource, schema, mutation) do
    attribute_fields =
      resource
      |> Ash.Resource.public_attributes()
      |> Enum.filter(fn attribute ->
        is_nil(mutation.action.accept) || attribute.name in mutation.action.accept
      end)
      |> Enum.filter(& &1.writable?)
      |> Enum.map(fn attribute ->
        type = field_type(attribute.type, attribute, resource)

        field_type =
          if attribute.allow_nil? || attribute.default || mutation.type == :update do
            type
          else
            %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: type
            }
          end

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type
        }
      end)

    relationship_fields =
      resource
      |> Ash.Resource.public_relationships()
      |> Enum.filter(fn relationship ->
        Resource in Ash.Resource.extensions(relationship.destination)
      end)
      |> Enum.map(fn
        %{cardinality: :one} = relationship ->
          type =
            if relationship.type == :belongs_to and relationship.required? do
              %Absinthe.Blueprint.TypeReference.NonNull{
                of_type: :id
              }
            else
              :id
            end

          %Absinthe.Blueprint.Schema.FieldDefinition{
            identifier: relationship.name,
            module: schema,
            name: to_string(relationship.name),
            type: type
          }

        %{cardinality: :many} = relationship ->
          case mutation.type do
            :update ->
              %Absinthe.Blueprint.Schema.FieldDefinition{
                identifier: relationship.name,
                module: schema,
                name: to_string(relationship.name),
                type: :relationship_change
              }

            :create ->
              %Absinthe.Blueprint.Schema.FieldDefinition{
                identifier: relationship.name,
                module: schema,
                name: to_string(relationship.name),
                type: %Absinthe.Blueprint.TypeReference.List{
                  of_type: :id
                }
              }
          end
      end)

    argument_fields =
      Enum.map(mutation.action.arguments, fn argument ->
        type =
          if argument.allow_nil? do
            %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: field_type(argument.type, argument, resource)
            }
          else
            field_type(argument.type, argument, resource)
          end

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: argument.name,
          module: schema,
          name: to_string(argument.name),
          type: type
        }
      end)

    attribute_fields ++ relationship_fields ++ argument_fields
  end

  defp query_type(:get, _, type), do: type
  # sobelow_skip ["DOS.StringToAtom"]
  defp query_type(:list, action, type) do
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

  defp args(action_type, resource, action, identity \\ nil)

  defp args(:get, _resource, _action, nil) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "id",
        identifier: :id,
        type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id},
        description: "The id of the record"
      }
    ]
  end

  defp args(:get, resource, _action, identity) do
    resource
    |> Ash.Resource.identities()
    |> Enum.find(&(&1.name == identity))
    |> Map.get(:keys)
    |> Enum.map(fn key ->
      attribute = Ash.Resource.attribute(resource, key)

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

  defp args(:list, resource, action, _) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "filter",
        identifier: :filter,
        type: resource_filter_type(resource),
        description: "A filter to limit the results"
      },
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "sort",
        identifier: :sort,
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: resource_sort_type(resource)
        },
        description: "How to sort the records in the response"
      }
    ] ++
      pagination_args(action)
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
        if action.pagination.required? && is_nil(action.pagination.default_limit) do
          %Absinthe.Blueprint.TypeReference.NonNull{
            of_type: :integer
          }
        else
          :integer
        end

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
      type_definition(resource, api, schema),
      sort_input(resource, schema),
      filter_input(resource, schema)
    ] ++
      filter_field_types(resource, schema) ++
      List.wrap(page_of(resource, schema)) ++ enum_definitions(resource, schema)
  end

  defp filter_field_types(resource, schema) do
    filter_attribute_types(resource, schema) ++ filter_aggregate_types(resource, schema)
  end

  defp filter_attribute_types(resource, schema) do
    resource
    |> Ash.Resource.public_attributes()
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp filter_aggregate_types(resource, schema) do
    resource
    |> Ash.Resource.public_aggregates()
    |> Enum.flat_map(&filter_type(&1, resource, schema))
  end

  defp attribute_or_aggregate_type(%Ash.Resource.Attribute{type: type}, _resource), do: type

  defp attribute_or_aggregate_type(%Ash.Resource.Aggregate{kind: kind, field: field}, resource) do
    field_type =
      if field do
        Ash.Resource.attribute(resource, field).type
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
            [_, {:ref, _}] ->
              false

            [{:ref, :any}, _] ->
              true

            [{:ref, type}, _] ->
              type in [type, Ash.Type.storage_type(type)]

            :any_same_or_ref ->
              true
          end)

        if Enum.any?(expressable_types, &(&1 == :any_same_or_ref)) do
          [
            %Absinthe.Blueprint.Schema.FieldDefinition{
              identifier: operator.name(),
              module: schema,
              name: to_string(operator.name()),
              type: field_type(type, attribute_or_aggregate, resource)
            }
          ]
        else
          type =
            case Enum.at(expressable_types, 0) do
              [_, {:array, :any}] ->
                {:array, Ash.Type.String}

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
                type: field_type(type, attribute_or_aggregate, resource)
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

  defp filter_input(resource, schema) do
    %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{
      identifier: resource_filter_type(resource),
      module: schema,
      name: resource |> resource_filter_type() |> to_string() |> Macro.camelize(),
      fields: resource_filter_fields(resource, schema)
    }
  end

  defp resource_filter_fields(resource, schema) do
    boolean_filter_fields(resource, schema) ++
      attribute_filter_fields(resource, schema) ++
      relationship_filter_fields(resource, schema) ++ aggregate_filter_fields(resource, schema)
  end

  defp attribute_filter_fields(resource, schema) do
    resource
    |> Ash.Resource.public_attributes()
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
    |> Ash.Resource.public_aggregates()
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
    |> Ash.Resource.public_relationships()
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
      |> Ash.Resource.public_attributes()
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

    attribute_sort_values = Enum.map(Ash.Resource.attributes(resource), & &1.name)
    aggregate_sort_values = Enum.map(Ash.Resource.aggregates(resource), & &1.name)

    sort_values = attribute_sort_values ++ aggregate_sort_values

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

  # sobelow_skip ["DOS.StringToAtom"]
  defp page_of(resource, schema) do
    type = Resource.type(resource)

    paginatable? =
      resource
      |> Ash.Resource.actions()
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

  defp type_definition(resource, api, schema) do
    type = Resource.type(resource)

    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: Ash.Resource.description(resource),
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
    resource
    |> Ash.Resource.public_attributes()
    |> Enum.map(fn
      %{name: :id} = attribute ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: :id,
          module: schema,
          name: "id",
          type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id}
        }

      attribute ->
        field_type = field_type(attribute.type, attribute, resource)

        field_type =
          if attribute.allow_nil? do
            field_type
          else
            %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: field_type
            }
          end

        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type
        }
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp relationships(resource, api, schema) do
    resource
    |> Ash.Resource.public_relationships()
    |> Enum.filter(fn relationship ->
      Resource in Ash.Resource.extensions(relationship.destination)
    end)
    |> Enum.map(fn
      %{cardinality: :one} = relationship ->
        type =
          if relationship.type == :belongs_to && relationship.required? do
            %Absinthe.Blueprint.TypeReference.NonNull{
              of_type: Resource.type(relationship.destination)
            }
          else
            Resource.type(relationship.destination)
          end

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
        read_action = Ash.Resource.primary_action!(relationship.destination, :read)

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
          arguments: args(:list, relationship.destination, read_action),
          type: query_type
        }
    end)
  end

  defp aggregates(resource, schema) do
    resource
    |> Ash.Resource.public_aggregates()
    |> Enum.map(fn aggregate ->
      field_type =
        if aggregate.field do
          Ash.Resource.attribute(resource, aggregate.field).type
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
    |> Ash.Resource.public_calculations()
    |> Enum.map(fn calculation ->
      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: calculation.name,
        module: schema,
        name: to_string(calculation.name),
        type: field_type(calculation.type, nil, resource)
      }
    end)
  end

  defp field_type({:array, type}, %Ash.Resource.Aggregate{} = aggregate, resource) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type(type, aggregate, resource)
    }
  end

  defp field_type({:array, type}, attribute, resource) do
    new_constraints = attribute.constraints[:items] || []
    new_attribute = %{attribute | constraints: new_constraints, type: type}

    if attribute.constraints[:nil_items?] do
      %Absinthe.Blueprint.TypeReference.List{
        of_type: field_type(type, new_attribute, resource)
      }
    else
      %Absinthe.Blueprint.TypeReference.List{
        of_type: %Absinthe.Blueprint.TypeReference.NonNull{
          of_type: field_type(type, new_attribute, resource)
        }
      }
    end
  end

  defp field_type(type, attribute, resource) do
    if Ash.Type.builtin?(type) do
      do_field_type(type, attribute, resource)
    else
      type.graphql_type(attribute, resource)
    end
  end

  defp do_field_type(Ash.Type.Atom, %{constraints: constraints, name: name}, resource) do
    if is_list(constraints[:one_of]) do
      atom_enum_type(resource, name)
    else
      :string
    end
  end

  defp do_field_type(Ash.Type.Map, _, _), do: :json
  defp do_field_type(Ash.Type.Term, _, _), do: :string
  defp do_field_type(Ash.Type.String, _, _), do: :string
  defp do_field_type(Ash.Type.Integer, _, _), do: :integer
  defp do_field_type(Ash.Type.Boolean, _, _), do: :boolean
  defp do_field_type(Ash.Type.UUID, _, _), do: :string
  defp do_field_type(Ash.Type.Date, _, _), do: :date
  defp do_field_type(Ash.Type.UtcDatetime, _, _), do: :naive_datetime

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
