defmodule AshGraphql.Api.Schema do
  defmacro __using__(opts) do
    quote bind_quoted: [api: opts[:api]] do
      defmodule __MODULE__.Schema do
        # use Absinthe.Schema

        @api api

        def __absinthe_lookup__(type) do
          __absinthe_type__(type)
        end

        def __absinthe_types__() do
          AshGraphql.Api.Schema.absinthe_types(@api)
        end

        def __absinthe_type__(type) do
          AshGraphql.Api.Schema.absinthe_type(@api, type)
        end

        def __absinthe_directives__() do
          AshGraphql.Api.Schema.Base.__absinthe_directives__()
        end

        def __absinthe_directive__(dir) do
          AshGraphql.Api.Schema.Base.__absinthe_directive__(dir)
        end

        def context(context) do
          context
        end

        def plugins() do
          [Absinthe.Middleware.Batch, Absinthe.Middleware.Async]
        end
      end
    end
  end

  defmodule Base do
    use Absinthe.Schema

    query do
    end

    # mutation do
    # end

    # subscription do
    # end
  end

  def absinthe_types(api, _), do: absinthe_types(api)

  def absinthe_types(api) do
    base_types = %{
      __directive: "__Directive",
      __directive_location: "__DirectiveLocation",
      __enumvalue: "__EnumValue",
      __field: "__Field",
      __inputvalue: "__InputValue",
      __schema: "__Schema",
      __type: "__Type",
      boolean: "Boolean",
      id: "ID",
      query: "RootQueryType",
      # mutation: "RootMutationType",
      # subscription: "RootSusbcriptionType",
      string: "String"
    }

    api
    |> resource_types()
    |> Enum.reduce(base_types, fn %{identifier: identifier, name: name}, acc ->
      Map.put(acc, identifier, name)
    end)
  end

  def absinthe_type(api, :query) do
    %Absinthe.Type.Object{
      __private__: [__absinthe_referenced__: true],
      __reference__: %{
        location: %{file: "nofile", line: 1},
        module: Module.concat(api, Schema)
      },
      definition: Module.concat(api, Schema),
      description: nil,
      fields:
        %{
          __schema: schema_type(),
          __type: type_type(),
          __typename: type_name_type()
        }
        |> add_query_fields(api),
      identifier: :query,
      interfaces: [],
      is_type_of: :object,
      name: "RootQueryType"
    }
  end

  def absinthe_type(api, type) do
    api
    |> resource_types()
    |> Enum.find(fn %{identifier: identifier} ->
      identifier == type
    end)
    |> case do
      nil ->
        AshGraphql.Api.Schema.Base.__absinthe_type__(type)

      type ->
        type
    end
  end

  defp resource_types(api) do
    api
    |> Ash.resources()
    |> Enum.filter(&(AshGraphql.GraphqlResource in &1.extensions))
    |> Enum.flat_map(&resource_types(api, &1))
  end

  defp add_query_fields(acc, api) do
    api
    |> Ash.resources()
    |> Enum.filter(&(AshGraphql.GraphqlResource in &1.extensions))
    |> Enum.flat_map(&query_fields(api, &1))
    |> Enum.reduce(acc, fn query_field, acc ->
      Map.put(acc, query_field.identifier, query_field)
    end)
  end

  defp query_fields(api, resource) do
    resource
    |> Ash.actions()
    |> Enum.flat_map(fn action ->
      case action do
        %{type: :read, primary?: true} ->
          read_action(api, resource, action)

        _ ->
          # TODO: Only support reads
          []
      end
    end)
  end

  # defp resource_types(api, resource) do
  #   resource_type(api, resource)
  #   # |> add_get_type(api, resource)
  # end

  defp resource_types(api, resource) do
    # NOT DONE
    pkey_field = :id

    # pkey_field =
    #   case Ash.primary_key(resource) do
    #     [field] ->
    #       field

    #     primary_key ->
    #       raise "Invalid primary key #{primary_key} for graphql resource"
    #   end

    get_one_identifier = String.to_atom(Ash.type(resource))
    get_many_identifier = String.to_atom(Ash.name(resource))

    [
      %Absinthe.Type.Object{
        __private__: [__absinthe_referenced__: true],
        __reference__: %{
          location: %{file: "nofile", line: 1},
          module: AshExample.Api.Schema
        },
        definition: AshExample.Api.Schema,
        description: Ash.describe(resource),
        fields:
          %{
            :__typename => type_name_type(),
            pkey_field => id_type(pkey_field)
          }
          |> add_fields(api, resource),
        identifier: get_one_identifier,
        interfaces: [],
        is_type_of: :object,
        name: String.capitalize(Atom.to_string(get_one_identifier))
      },
      page_of(get_one_identifier, get_many_identifier)
    ]
  end

  defp add_fields(fields, _api, _resource) do
    fields
    # name: %Absinthe.Type.Field{
    #   __private__: [],
    #   __reference__: %{
    #     location: %{file: "nofile", line: 1},
    #     module: AshExample.Api.Schema
    #   },
    #   args: %{},
    #   complexity:
    #     {:ref, AshExample.Api.Schema,
    #      {Absinthe.Blueprint.Schema.FieldDefinition, {:item, :name}}},
    #   config:
    #     {:ref, AshExample.Api.Schema,
    #      {Absinthe.Blueprint.Schema.FieldDefinition, {:item, :name}}},
    #   default_value: nil,
    #   definition: AshExample.Api.Schema,
    #   deprecation: nil,
    #   description: nil,
    #   identifier: :name,
    #   middleware: [{Absinthe.Middleware.MapGet, :name}],
    #   name: "name",
    #   triggers:
    #     {:ref, AshExample.Api.Schema,
    #      {Absinthe.Blueprint.Schema.FieldDefinition, {:item, :name}}},
    #   type: :string
    # }
  end

  defp read_action(api, resource, action) do
    # If not primary action, we need to give it a different name
    get_one_identifier = String.to_atom(Ash.type(resource))
    get_many_identifier = String.to_atom(Ash.name(resource))

    [
      %Absinthe.Type.Field{
        __private__: [],
        __reference__: %{
          location: %{file: "nofile", line: 1},
          module: AshExample.Api.Schema
        },
        args: %{
          id: %Absinthe.Type.Argument{
            __reference__: nil,
            default_value: nil,
            definition: nil,
            deprecation: nil,
            description: nil,
            identifier: :id,
            name: "id",
            type: %Absinthe.Type.NonNull{of_type: :id}
          }
        },
        # TODO: DO THIS
        complexity: 2,
        config: %{},
        default_value: nil,
        definition: AshExample.Api.Schema,
        deprecation: nil,
        description: nil,
        identifier: get_one_identifier,
        middleware: [
          {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, :get, action.name}}
        ],
        name: Atom.to_string(get_one_identifier),
        triggers: [],
        type: get_one_identifier
      },
      %Absinthe.Type.Field{
        __private__: [],
        __reference__: %{
          location: %{file: "nofile", line: 1},
          module: AshExample.Api.Schema
        },
        args: %{
          limit: %Absinthe.Type.Argument{
            identifier: :limit,
            type: :integer,
            name: "limit"
          },
          offset: %Absinthe.Type.Argument{
            identifier: :offset,
            default_value: 0,
            type: :integer,
            name: "offset"
          }
          # TODO: Generate types for the filter, sort, and paginate args
          # Also figure out graphql pagination
          # filter: %Absinthe.Type.Argument
          # id: %Absinthe.Type.Argument{
          #   __reference__: nil,
          #   default_value: nil,
          #   definition: nil,
          #   deprecation: nil,
          #   description: nil,
          #   identifier: :id,
          #   name: "id",
          #   type: %Absinthe.Type.NonNull{of_type: :id}
          # }
        },
        complexity: 1,
        config: %{},
        default_value: nil,
        definition: AshExample.Api.Schema,
        deprecation: nil,
        description: nil,
        identifier: get_many_identifier,
        middleware: [
          {{AshGraphql.Graphql.Resolver, :resolve}, {api, resource, :read, action.name}}
        ],
        name: Atom.to_string(get_many_identifier),
        triggers: [],
        type: String.to_atom("page_of_#{get_many_identifier}")
      }
    ]
  end

  defp page_of(get_one_identifier, get_many_identifier) do
    %Absinthe.Type.Object{
      __private__: [__absinthe_referenced__: true],
      __reference__: %{
        location: %{file: "nofile", line: 1},
        module: AshExample.Api.Schema
      },
      definition: AshExample.Api.Schema,
      description: "A page of #{get_many_identifier}",
      fields: %{
        __typename: type_name_type(),
        offset: %Absinthe.Type.Field{
          __private__: [],
          __reference__: %{
            location: %{file: "nofile", line: 1},
            module: AshExample.Api.Schema
          },
          args: %{},
          # TODO: DO THIS
          complexity: 1,
          config: %{},
          default_value: nil,
          definition: AshExample.Api.Schema,
          deprecation: nil,
          description: nil,
          identifier: :offset,
          middleware: [{Absinthe.Middleware.MapGet, :offset}],
          name: "offset",
          triggers: [],
          type: :integer
        },
        limit: %Absinthe.Type.Field{
          __private__: [],
          __reference__: %{
            location: %{file: "nofile", line: 1},
            module: AshExample.Api.Schema
          },
          args: %{},
          # TODO: DO THIS
          complexity: 1,
          config: %{},
          default_value: nil,
          definition: AshExample.Api.Schema,
          deprecation: nil,
          description: nil,
          identifier: :limit,
          middleware: [{Absinthe.Middleware.MapGet, :limit}],
          name: "limit",
          triggers: [],
          type: :integer
        },
        results: %Absinthe.Type.Field{
          __private__: [],
          __reference__: %{
            location: %{file: "nofile", line: 1},
            module: AshExample.Api.Schema
          },
          args: %{},
          # TODO: DO THIS
          complexity: 1,
          config: %{},
          default_value: nil,
          definition: AshExample.Api.Schema,
          deprecation: nil,
          description: nil,
          identifier: :results,
          middleware: [{Absinthe.Middleware.MapGet, :results}],
          name: "results",
          triggers: [],
          type: %Absinthe.Type.NonNull{
            of_type: %Absinthe.Type.List{
              of_type: %Absinthe.Type.NonNull{of_type: get_one_identifier}
            }
          }
        }
      },
      identifier: String.to_atom("page_of_#{get_many_identifier}"),
      interfaces: [],
      is_type_of: :object,
      name: "pageOf#{String.capitalize(Atom.to_string(get_many_identifier))}"
    }
  end

  defp id_type(field) do
    %Absinthe.Type.Field{
      __private__: [],
      __reference__: %{
        location: %{file: "nofile", line: 1},
        module: AshExample.Api.Schema
      },
      args: %{},
      # TODO: do this
      complexity: 1,
      config: %{},
      default_value: nil,
      definition: AshExample.Api.Schema,
      deprecation: nil,
      description: nil,
      identifier: :id,
      middleware: [{Absinthe.Middleware.MapGet, field}],
      name: "id",
      triggers: [],
      type: :id
    }
  end

  defp schema_type() do
    %Absinthe.Type.Field{
      __private__: [],
      __reference__: %{
        location: %{
          file:
            "/Users/zachdaniel/dev/ash/ash_example/deps/absinthe/lib/absinthe/phase/schema/introspection.ex",
          line: 116
        },
        module: Absinthe.Phase.Schema.Introspection
      },
      args: %{},
      complexity: nil,
      config: nil,
      default_value: nil,
      definition: Absinthe.Phase.Schema.Introspection,
      deprecation: nil,
      description: "Represents the schema",
      identifier: :__schema,
      middleware: [
        {{Absinthe.Middleware, :shim},
         {:query, :__schema, [{:ref, Absinthe.Phase.Schema.Introspection, :schema}]}}
      ],
      name: "__schema",
      triggers: %{},
      type: :__schema
    }
  end

  def type_name_type() do
    %Absinthe.Type.Field{
      __private__: [],
      __reference__: %{
        location: %{
          file:
            "/Users/zachdaniel/dev/ash/ash_example/deps/absinthe/lib/absinthe/phase/schema/introspection.ex",
          line: 74
        },
        module: Absinthe.Phase.Schema.Introspection
      },
      args: %{},
      complexity: 0,
      config: 0,
      default_value: nil,
      definition: Absinthe.Phase.Schema.Introspection,
      deprecation: nil,
      description: "The name of the object type currently being queried.",
      identifier: :__typename,
      middleware: [
        {{Absinthe.Middleware, :shim},
         {:query, :__typename, [{:ref, Absinthe.Phase.Schema.Introspection, :typename}]}}
      ],
      name: "__typename",
      triggers: %{},
      type: :string
    }
  end

  def type_type() do
    %Absinthe.Type.Field{
      __private__: [],
      __reference__: %{
        location: %{
          file:
            "/Users/zachdaniel/dev/ash/ash_example/deps/absinthe/lib/absinthe/phase/schema/introspection.ex",
          line: 80
        },
        module: Absinthe.Phase.Schema.Introspection
      },
      args: %{
        name: %Absinthe.Type.Argument{
          __reference__: nil,
          default_value: nil,
          definition: nil,
          deprecation: nil,
          description: "The name of the type to introspect",
          identifier: :name,
          name: "name",
          type: %Absinthe.Type.NonNull{of_type: :string}
        }
      },
      complexity: nil,
      config: nil,
      default_value: nil,
      definition: Absinthe.Phase.Schema.Introspection,
      deprecation: nil,
      description: "Represents scalars, interfaces, object types, unions, enums in the system",
      identifier: :__type,
      middleware: [
        {{Absinthe.Middleware, :shim},
         {:query, :__type, [{:ref, Absinthe.Phase.Schema.Introspection, :type}]}}
      ],
      name: "__type",
      triggers: %{},
      type: :__type
    }
  end
end

#   defmacro __using__(opts \\ []) do
#     quoted =
#       quote do
#         for resource <- Ash.resources(unquote(opts[:api])) do
#         end
#       end

#     quote do
#       defmodule(__MODULE__.Schema, do: unquote(quoted))
#     end
#   end
# end
