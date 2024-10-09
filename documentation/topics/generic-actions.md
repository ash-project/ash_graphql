# Generic Actions

Generic actions allow us to build any interface we want in Ash. AshGraphql
has full support for generic actions, from type generation to data loading.

This means that you can write actions that return records or lists of records
and those will have all of their fields appropriately loadable, or you can have
generic actions that return simple scalars, like integers or strings.

## Examples

Here we have a simple generic action returning a scalar value.

```elixir
graphql do
  queries do
    action :say_hello, :say_hello
  end
end

actions do
  action :say_hello, :string do
    argument :to, :string, allow_nil?: false

    run fn input, _ ->
      {:ok, "Hello, #{input.arguments.to}"}
    end
  end
end
```

And here we have a generic action returning a list of records.

```elixir
graphql do
  type :post

  queries do
    action :random_ten, :random_ten
  end
end

actions do
  action :random_ten, {:array, :struct} do
    constraints items: [instance_of: __MODULE__]

    run fn input, context ->
      # This is just an example, not an efficient way to get
      # ten random records
      with {:ok, records} <-  Ash.read(__MODULE__) do
        {:ok, Enum.take_random(records, 10)}
      end
    end
  end
end
```
