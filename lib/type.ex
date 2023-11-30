defmodule AshGraphql.Type do
  @moduledoc """
  Callbacks used to enrich types with GraphQL-specific metadata.
  """

  defmacro __using__(_) do
    quote do
      @behaviour AshGraphql.Type
    end
  end

  @doc """
  Sets the name of the graphql type for a given Ash type. For example: `:weekday`.

  This will do different things depending on the type you're adding it to.

  ## Regular Types

  This expresses that you will define a custom type for representing this in your graphql

  ## NewTypes
  If it is a subtype of a union, or map/keyword with `fields` the type will be *created* with that name.
  So you can use this to decide what it will be named. Otherwise, it behaves as stated above for
  regular types.
  """
  @callback graphql_type(Ash.Type.constraints()) :: :atom

  @doc """
  Sets the name of the graphql input type for a given Ash type. For example: `:weekday`.

  This will do different things depending on the type you're adding it to.

  ## Regular Types

  This expresses that you will define a custom type for representing this input in your graphql

  ## NewTypes
  If it is a subtype of a union, or map/keyword with `fields` the type will be *created* with that name.
  So you can use this to decide what it will be named. Otherwise, it behaves as stated above for
  regular types.
  """
  @callback graphql_input_type(Ash.Type.constraints()) :: :atom

  @doc """
  Used for `Ash.Type.Enum` to rename individual values. For example:

  ```elixir
  defmodule MyEnum do
    use Ash.Type.Enum, values: [:foo, :bar, :baz]

    def graphql_rename_value(:baz), do: :buz
    def graphql_rename_value(other), do: other
  end
  ```
  """
  @callback graphql_rename_value(Ash.Type.constraints()) :: String.t() | :atom

  @doc """
  Used for map/embedded types embedded in unions, to avoid nesting them in a key by their name.

  See [the unions guide](/documentation/how_to/use-unions-with-graphql.md) for more.
  """
  @callback graphql_unnested_unions(Ash.Type.constraints()) :: [atom()]

  @optional_callbacks graphql_type: 1,
                      graphql_input_type: 1,
                      graphql_rename_value: 1,
                      graphql_unnested_unions: 1
end
