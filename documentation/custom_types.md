# Custom Types

When defining an ash type, you can simply define `graphql_type/1` and `graphql_input_type/1`. For example, a custom object type like the following.

```elixir
defmodule AshGraphql.Test.Foo do
  @moduledoc false

  use Ash.Type

  def graphql_type(_constraints), do: :foo
  def graphql_input_type(_constraints), do: :foo_input

  @impl true
  def storage_type, do: :map

  @impl true
  def cast_input(value, _) when is_map(value), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(value, _) when is_map(value), do: {:ok, value}
  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(value, _) when is_map(value), do: {:ok, value}
  def dump_to_native(_, _), do: :error
end
```

Then, in your absinthe schema, you can define the corresponding graphql objects:

```elixir
object :foo do
  ...
end

input_object :foo_input do
  ...
end
```

Generally speaking, you should prefer to use *embedded resources* for custom key/value objects (a guide can be found in the core ash documentation), but this can be a useful escape hatch in some cases.