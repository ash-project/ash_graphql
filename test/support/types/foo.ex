defmodule AshGraphql.Test.Foo do
  use Ash.Type

  def graphql_type(_), do: :foo
  def graphql_input_type(_), do: :foo_input

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
