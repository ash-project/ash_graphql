defmodule AshGraphql.GraphqlResource do
  @callback graphql_fields() :: [%AshGraphql.GraphqlResource.Field{}]
  @callback graphql_type() :: atom

  defmacro __using__(_) do
    quote do
      @extensions AshGraphql.GraphqlResource
      @behaviour AshGraphql.GraphqlResource
      @graphql_type nil
      Module.register_attribute(__MODULE__, :graphql_fields, accumulate: true)

      import AshGraphql.GraphqlResource, only: [graphql: 1]
    end
  end

  defmacro graphql(do: body) do
    quote do
      import AshGraphql.GraphqlResource, only: [fields: 1, type: 1]
      unquote(body)
      import AshGraphql.GraphqlResource, only: [graphql: 1]
    end
  end

  defmacro fields(do: body) do
    quote do
      import AshGraphql.GraphqlResource, only: [field: 2, field: 3]

      unquote(body)

      import AshGraphql.GraphqlResource, only: [fields: 1, type: 1]
    end
  end

  defmacro type(type) do
    quote do
      @graphql_type unquote(type)
    end
  end

  defmacro field(name, action, opts \\ []) do
    quote do
      field = AshGraphql.GraphqlResource.Field.new(unquote(name), unquote(action), unquote(opts))
      @graphql_fields field
    end
  end

  @doc false
  def before_compile_hook(_env) do
    quote do
      unless @graphql_type do
        raise "Must set graphql type for #{__MODULE__}"
      end

      def graphql_type() do
        @graphql_type
      end

      def graphql_fields() do
        @graphql_fields
      end
    end
  end
end
