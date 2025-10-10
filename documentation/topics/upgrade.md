<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Upgrading to 1.0

AshGraphql 1.0 is a major release that introduces 3.0 support as well as a few
breaking changes for AshGraphql itself.

## `:datetime` is now the default representation for datetimes

For backwards compatibility, pre-1.0 we had users configure `:utc_datetime_type` to `:datetime` as part of the getting started guide. This is now the default. The configuration remains, but has been renamed. It was improperly `config :ash, :utc_datetime_type`, and it is now `config :ash_graphql, :utc_datetime_type`. If you are a user who is relying on the original behavior that had it default to `:naive_datetime`, you can set the following configuration:

```elixir
config :ash_graphql, :utc_datetime_type, :naive_datetime
```

Otherwise, if you have the following in your config, you can remove it.

```elixir
config :ash, :utc_datetime_type, :datetime
```

## `allow_non_null_mutation_arguments?` is now `true` always

You can remove this code from your config.

```elixir
config :ash_graphql, :allow_non_null_mutation_arguments?, true
```

Pre 1.0, the `input` argument for mutations was always allowed to be `null`. In 1.0, it will be required if there are any non-null inputs inside of the object. You may need to address clients that are expecting to be able to send `null`. Even if they _were_ sending `null` in those cases, it would have been an error, so it is unlikely that you will have to make any changes here.

---

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

---

## The `managed_relationships.auto?` option now defaults to `true`

Pre 1.0, you would need to either configure managed_relationships manually, for example:

```elixir
managed_relationships do
  managed_relationship :create, :comments
end
```

Or set `auto?` to `true`, which would derive appropriate configurations for any action that had arguments with corresponding `manage_relationship` changes for them. This is unnecessarily verbose and there isn't really a time where you wouldn't want an input type derived for an argument that uses `change manage_relationship`, so the default for `auto?` is now `true`. This only affects arguments who's type is `:map`, or `{:array, :map}`.

A new option has been added to `managed_relationship` to allow you to bypass this type generation if necessary:

```elixir
managed_relationships do
  managed_relationship :create, :comments, ignore?: true
end
```

## `Ash.Api` is now `Ash.Domain` in Ash 3.0

Your Absinthe schema file (ie. `MyApp.Schema`) will need all references to `api` updated to be `domain`. eg.

```elixir
@domains [MyApp.Domain1, MyApp.Domain2]

use AshGraphql, domains: @domains
```
