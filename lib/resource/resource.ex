defmodule AshGraphql.Resource do
  @get %Ash.Dsl.Entity{
    name: :get,
    args: [:name, :action],
    describe: "A query to fetch a record by primary key",
    examples: [
      "get :get_post, :default"
    ],
    schema: AshGraphql.Resource.Query.get_schema(),
    target: AshGraphql.Resource.Query,
    auto_set_fields: [
      type: :get
    ]
  }

  @list %Ash.Dsl.Entity{
    name: :list,
    schema: AshGraphql.Resource.Query.list_schema(),
    args: [:name, :action],
    describe: "A query to fetch a list of records",
    examples: [
      "list :list_posts, :default"
    ],
    target: AshGraphql.Resource.Query,
    auto_set_fields: [
      type: :list
    ]
  }

  @create %Ash.Dsl.Entity{
    name: :create,
    schema: AshGraphql.Resource.Mutation.create_schema(),
    args: [:name, :action],
    describe: "A mutation to create a record",
    examples: [
      "create :create_post, :default"
    ],
    target: AshGraphql.Resource.Mutation,
    auto_set_fields: [
      type: :create
    ]
  }

  @update %Ash.Dsl.Entity{
    name: :update,
    schema: AshGraphql.Resource.Mutation.update_schema(),
    args: [:name, :action],
    describe: "A mutation to update a record",
    examples: [
      "update :update_post, :default"
    ],
    target: AshGraphql.Resource.Mutation,
    auto_set_fields: [
      type: :update
    ]
  }

  @destroy %Ash.Dsl.Entity{
    name: :destroy,
    schema: AshGraphql.Resource.Mutation.destroy_schema(),
    args: [:name, :action],
    describe: "A mutation to destroy a record",
    examples: [
      "destroy :destroy_post, :default"
    ],
    target: AshGraphql.Resource.Mutation,
    auto_set_fields: [
      type: :destroy
    ]
  }

  @queries %Ash.Dsl.Section{
    name: :queries,
    describe: """
    Queries (read actions) to expose for the resource.
    """,
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
    schema: [
      type: [
        type: :atom,
        required: true,
        doc: "The type to use for this entity in the graphql schema"
      ],
      fields: [
        type: {:custom, __MODULE__, :__fields, []},
        required: true,
        doc: "The fields from this entity to include in the graphql"
      ]
    ],
    sections: [
      @queries,
      @mutations
    ]
  }

  @doc false
  def __fields(fields) do
    fields = List.wrap(fields)

    if Enum.all?(fields, &is_atom/1) do
      {:ok, fields}
    else
      {:error, "Expected `fields` to be a list of atoms"}
    end
  end

  @transformers [
    AshJsonApi.Resource.Transformers.RequireIdPkey
  ]

  use Ash.Dsl.Extension, sections: [@graphql], transformers: @transformers

  def queries(resource) do
    Ash.Dsl.Extension.get_entities(resource, [:graphql, :queries])
  end

  def mutations(resource) do
    Ash.Dsl.Extension.get_entities(resource, [:graphql, :mutations])
  end

  def type(resource) do
    Ash.Dsl.Extension.get_opt(resource, [:graphql], :type, nil)
  end

  def fields(resource) do
    Ash.Dsl.Extension.get_opt(resource, [:graphql], :fields, [])
  end

  @doc false
  def queries(api, resource, schema) do
    type = AshGraphql.Resource.type(resource)

    resource
    |> queries()
    |> Enum.map(fn query ->
      %Absinthe.Blueprint.Schema.FieldDefinition{
        arguments: args(query.type),
        identifier: query.name,
        middleware: [
          {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, query.type, query.action}}
        ],
        module: schema,
        name: to_string(query.name),
        type: query_type(query.type, type)
      }
    end)
  end

  @doc false
  def mutations(api, resource, schema) do
    resource
    |> mutations()
    |> Enum.map(fn
      %{type: :destroy} = mutation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: [
            %Absinthe.Blueprint.Schema.InputValueDefinition{
              identifier: :id,
              module: schema,
              name: "id",
              placement: :argument_definition,
              type: :id
            }
          ],
          identifier: mutation.name,
          middleware: [
            {{AshGraphql.Graphql.Resolver, :mutate},
             {api, resource, mutation.type, mutation.action}}
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
            {{AshGraphql.Graphql.Resolver, :mutate},
             {api, resource, mutation.type, mutation.action}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result")
        }

      mutation ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          arguments: [
            %Absinthe.Blueprint.Schema.InputValueDefinition{
              identifier: :id,
              module: schema,
              name: "id",
              placement: :argument_definition,
              type: :id
            },
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
            {{AshGraphql.Graphql.Resolver, :mutate},
             {api, resource, mutation.type, mutation.action}}
          ],
          module: schema,
          name: to_string(mutation.name),
          type: String.to_atom("#{mutation.name}_result")
        }
    end)
  end

  @doc false
  def mutation_types(resource, schema) do
    resource
    |> mutations()
    |> Enum.flat_map(fn mutation ->
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
            type: AshGraphql.Resource.type(resource)
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

  defp mutation_fields(resource, schema, query) do
    fields = AshGraphql.Resource.fields(resource)

    attribute_fields =
      resource
      |> Ash.Resource.attributes()
      |> Enum.filter(&(&1.name in fields))
      |> Enum.filter(& &1.writable?)
      |> Enum.map(fn attribute ->
        type = field_type(attribute.type)

        field_type =
          if attribute.allow_nil? || query.type == :update do
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
      |> Ash.Resource.relationships()
      |> Enum.filter(&(&1.name in fields))
      |> Enum.filter(fn relationship ->
        AshGraphql.Resource in Ash.Resource.extensions(relationship.destination)
      end)
      |> Enum.map(fn
        %{cardinality: :one} = relationship ->
          %Absinthe.Blueprint.Schema.FieldDefinition{
            identifier: relationship.name,
            module: schema,
            name: to_string(relationship.name),
            type: :id
          }

        %{cardinality: :many} = relationship ->
          case query.type do
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

    attribute_fields ++ relationship_fields
  end

  defp query_type(:get, type), do: type
  defp query_type(:list, type), do: String.to_atom("page_of_#{type}")

  defp args(:get) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "id",
        identifier: :id,
        type: :id,
        description: "The id of the record"
      }
    ]
  end

  defp args(:list) do
    [
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "limit",
        identifier: :limit,
        type: :integer,
        description: "The limit of records to return",
        default_value: 20
      },
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "offset",
        identifier: :offset,
        type: :integer,
        description: "The count of records to skip",
        default_value: 0
      },
      %Absinthe.Blueprint.Schema.InputValueDefinition{
        name: "filter",
        identifier: :filter,
        type: :string,
        description: "A json encoded filter to apply"
      }
    ]
  end

  @doc false
  def type_definitions(resource, schema) do
    [
      type_definition(resource, schema),
      page_of(resource, schema)
    ]
  end

  defp page_of(resource, schema) do
    type = AshGraphql.Resource.type(resource)

    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "A page of #{inspect(type)}",
      fields: [
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: "The records contained in the page",
          identifier: :results,
          module: schema,
          name: "results",
          type: %Absinthe.Blueprint.TypeReference.List{
            of_type: type
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
  end

  defp type_definition(resource, schema) do
    type = AshGraphql.Resource.type(resource)

    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: Ash.Resource.description(resource),
      fields: fields(resource, schema),
      identifier: type,
      module: schema,
      name: Macro.camelize(to_string(type))
    }
  end

  defp fields(resource, schema) do
    fields = AshGraphql.Resource.fields(resource)

    attributes(resource, schema, fields) ++
      relationships(resource, schema, fields) ++
      aggregates(resource, schema, fields)
  end

  defp attributes(resource, schema, fields) do
    resource
    |> Ash.Resource.attributes()
    |> Enum.filter(&(&1.name in fields))
    |> Enum.map(fn
      %{name: :id} = attribute ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: :id,
          module: schema,
          name: "id",
          type: :id
        }

      attribute ->
        %Absinthe.Blueprint.Schema.FieldDefinition{
          description: attribute.description,
          identifier: attribute.name,
          module: schema,
          name: to_string(attribute.name),
          type: field_type(attribute.type)
        }
    end)
  end

  defp relationships(resource, schema, fields) do
    resource
    |> Ash.Resource.relationships()
    |> Enum.filter(&(&1.name in fields))
    |> Enum.filter(fn relationship ->
      AshGraphql.Resource in Ash.Resource.extensions(relationship.destination)
    end)
    |> Enum.map(fn
      %{cardinality: :one} = relationship ->
        type = AshGraphql.Resource.type(relationship.destination)

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(relationship.name),
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc}, {:one, relationship.name}}
          ],
          arguments: [],
          type: type
        }

      %{cardinality: :many} = relationship ->
        type = AshGraphql.Resource.type(relationship.destination)
        query_type = String.to_atom("page_of_#{type}")

        %Absinthe.Blueprint.Schema.FieldDefinition{
          identifier: relationship.name,
          module: schema,
          name: to_string(relationship.name),
          middleware: [
            {{AshGraphql.Graphql.Resolver, :resolve_assoc}, {:many, relationship.name}}
          ],
          arguments: args(:list),
          type: query_type
        }
    end)
  end

  defp aggregates(resource, schema, fields) do
    resource
    |> Ash.Resource.aggregates()
    |> Enum.filter(&(&1.name in fields))
    |> Enum.map(fn aggregate ->
      {:ok, type} = Ash.Query.Aggregate.kind_to_type(aggregate.kind)

      %Absinthe.Blueprint.Schema.FieldDefinition{
        identifier: aggregate.name,
        module: schema,
        name: to_string(aggregate.name),
        type: field_type(type)
      }
    end)
  end

  defp field_type(Ash.Type.String), do: :string
  defp field_type(Ash.Type.UUID), do: :string
  defp field_type(Ash.Type.Integer), do: :integer

  defp field_type({:array, type}) do
    %Absinthe.Blueprint.TypeReference.List{
      of_type: field_type(type)
    }
  end
end
