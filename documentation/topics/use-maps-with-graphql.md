# Use Maps with GraphQL

If you define an `Ash.Type.NewType` that is a subtype of `:map`, _and_ you add the `fields` constraint which specifies field names and their types, `AshGraphql` will automatically derive an appropriate GraphQL type for it.

For example:

```elixir
defmodule MyApp.Types.Metadata do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :map, constraints: [
    fields: [
      title: [
        type: :string
      ],
      description: [
        type: :string
      ]
    ]
  ]

  def graphql_type(_), do: :metadata
end

```

## Bypassing type generation for an map

Add the `graphql_define_type?/1` callback, like so, to skip Ash's generation (i.e if you're defining it yourself)

```elixir
@impl true
def graphql_define_type?(_), do: false
```
