# Use Enums with GraphQL

If you define an `Ash.Type.Enum`, that enum type can be used both in attributes _and_ arguments. You will need to add `graphql_type/0` to your implementation. AshGraphql will ensure that a single type is defined for it, which will be reused across all occurrences. If an enum
type is referenced, but does not have `graphql_type/0` defined, it will
be treated as a string input.

For example:

```elixir
defmodule AshPostgres.Test.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:open, :closed]

  def graphql_type, do: :ticket_status

  # Optionally, remap the names used in GraphQL, for instance if you have a value like `:"10"`
  # that value is not compatible with GraphQL

  def graphql_rename_value(:"10"), do: :ten
  def graphql_rename_value(value), do: value

  # You can also provide descriptions for the enum values, which will be exposed in the GraphQL
  # schema.
  # Remember to have a fallback clause that returns nil if you don't provide descriptions for all
  # values.

  def graphql_describe_enum_value(:open), do: "The post is open"
  def graphql_describe_enum_value(_), do: nil
end

```

### Using custom absinthe types

You can implement a custom enum by first adding the enum type to your absinthe schema (more [here](https://hexdocs.pm/absinthe/Absinthe.Type.Enum.html)). Then you can define a custom Ash type that refers to that absinthe enum type.

```elixir
# In your absinthe schema:

enum :status do
  value(:open, description: "The post is open")
  value(:closed, description: "The post is closed")
end
```

```elixir
# Your custom Ash Type
defmodule AshGraphql.Test.Status do
  use Ash.Type

  @values [:open, :closed]
  @string_values Enum.map(@values, &to_string/1)

  def graphql_input_type(_), do: :status
  def graphql_type(_), do: :status

  @impl true
  def storage_type, do: :string

  @impl true
  def cast_input(value, _) when value in @values do
    {:ok, value}
  end

  def cast_input(value, _) when is_binary(value) do
    value = String.downcase(value)

    if value in @string_values do
      {:ok, String.to_existing_atom(value)}
    else
      :error
    end
  end

  @impl true
  def cast_stored(value, _) when value in @values do
    {:ok, value}
  end

  def cast_stored(value, _) when value in @string_values do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError ->
      :error
  end

  @impl true
  def dump_to_native(value, _) when is_atom(value) do
    {:ok, to_string(value)}
  end

  def dump_to_native(_, _), do: :error
end
```
