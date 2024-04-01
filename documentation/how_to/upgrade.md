# Upgrading to 1.0

AshGraphql 1.0 is a major release that introduces 3.0 support as well as a few
breaking changes for AshGraphql itself.

## Automagic atom/union/map types are no more

Pre 1.0: AshGraphql automatically generated types for attributes/arguments that were atom/union/map types, giving them a name like `postStatus`, for an attribute `status` on a resource `post`. While convenient, this incurred _significant_ internal complexity, and had room for strange ambiguity. For example, if you had two actions, that each had an argument called `:status`, and that `:status` was an enum with different values, you would get a conflict at compile time due to conflicting type names.

### What you'll need to change

AshGraphql will now _only_ generate types for types defined using `Ash.Type.NewType` or `Ash.Type.Enum`. For example, if you had:

```elixir
attribute :post_status, :atom, constraints: [one_of: [:active, :archived]]
```

in 3.0 this attribute would display as a `:string`. To fix this, you would define an `Ash.Type.Enum`:

```elixir
defmodule MyApp.PostStatus do
  use Ash.Type.Enum, values: [:active, :archived]

  def graphql_type(_), do: :post_status
  def graphql_input_type(_), do: :post_status
end
```

Then you could use it in your attribute:

```elixir
attribute :post_status, MyApp.PostStatus
```

The same goes for map types with the `:fields` constraint, as well as union types, except you must define those using `Ash.Type.NewType`. For example:

```elixir
attribute :scale, :union, constraints: [
  types: [
    whole: [
      type: :integer
    ],
    fractional: [
      type: :decimal
    ]
  ]
]
```

Here you would get a compile error, indicating that we cannot determine a type for `:union`. To resolve this, you would define an `Ash.Type.NewType`, like so:

```elixir
defmodule MyApp.Scale do
  use Ash.Type.NewType, subtype_of: :union, constraints: [
    types: [
      whole: [
        type: :integer
      ],
      fractional: [
        type: :decimal
      ]
    ]
  ]

  def graphql_type(_), do: :scale
  def graphql_input_type(_), do: :scale
end
```

Then you could use it in your application like so:

```elixir
attribute :scale, MyApp.Scale
```
