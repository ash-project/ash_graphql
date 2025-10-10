<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Use Unions with GraphQL

Unions must be defined with `Ash.Type.NewType`:

```elixir
defmodule MyApp.Armor do
  use Ash.Type.NewType, subtype_of: :union, constraints: [
    types: [
      plate: [
        # This is an embedded resource, with its own fields
        type: MyApp.Armor.Plate
      ],
      chain_mail: [
        # And so is this
        type: MyApp.Armor.ChainMail
      ],
      custom: [
        type: :string
      ]
    ]
  ]

  use AshGraphql.Type

  # Add this to define the union in ash_graphql
  def graphql_type(_), do: :armor
end
```

By default, the type you would get for this on input and output would look something like this:

```
type Armor = {plate: {value: Plate}} | {chain_mail: {value: ChainMail}} | {custom: {value: String}}
```

We do this by default to solve for potentially ambiguous types. An example of this might be if you had multiple different types of strings in a union, and you wanted the client to be able to tell exactly which type of string they'd been given. i.e `{social: {value: "555-55-5555"}} | {phone_number: {value: "555-5555"}}`.

However, you can clean the type in cases where you have no such conflicts by by providing

```elixir
# Put anything in here that does not need to be named/nested with `{type_name: {value: value}}`
def graphql_unnested_unions(_constraints), do: [:plate, :chain_mail]
```

Which, in this case, would yield:

```
type Armor = Plate | ChainMail | {custom: {value: String}}
```

## Bypassing type generation for a union

Add the `graphql_define_type?/1` callback, like so, to skip Ash's generation (i.e if you're defining it yourself)

```elixir
@impl true
def graphql_define_type?(_), do: false
```
