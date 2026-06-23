<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Relay

Enabling Relay for a resource sets it up to follow the [Relay specification](https://relay.dev/graphql/connections.htm).

The two changes that are made currently are:

- the type for the resource will implement the `Node` interface
- pagination over that resource will behave as a `Connection`.

## Using Ash's built-in Relay support

Set `relay? true` on the resource:

```elixir
graphql do
  relay? true

  ...
end
```

## Relay Global IDs

Use the following option to generate Relay Global IDs (see
[here](https://relay.dev/graphql/objectidentification.htm)).

```elixir
use AshGraphql, relay_ids?: true
```

This allows refetching a node using the `node` query and passing its global ID.

### Filtering with Relay global IDs

When a resource uses a non-string or non-UUID primary key, GraphQL filter inputs normally use the
native Ash attribute type (for example `Int` for integer primary keys). To accept Relay global IDs in
filters, configure per-field handlers on the resource:

```elixir
graphql do
  filter_handlers [
    id: [
      type: :id,
      handler: {AshGraphql.Graphql.FilterHandlers, :relay_id, [:base_image]},
      description: "Filter by Relay global ID"
    ]
  ]
end
```

Each handler is an MFA invoked as `handler.(value, context)`. The handler receives the filter operand
(for example a Relay global ID string) and a context map with `:resource`, `:field`, `:operator`,
`:handler_args`, `:relay_ids?`, `:actor`, and `:tenant`. It must return an Ash expression used in the
resulting filter.

`AshGraphql.Graphql.FilterHandlers.relay_id/2` decodes Relay global IDs using the type given in the
handler MFA's extra arguments (for example `[:base_image]`). For `:eq` it returns
`expr(^ref(field) == ^decoded_value)`; for `:in` it returns `expr(^ref(field) in ^decoded_values)`.


### Translating Relay Global IDs passed as arguments

When `relay_ids?: true` is passed, users of the API will have access only to the global IDs, so they
will also need to use them when an ID is required as argument. You actions, though, internally use the
normal IDs defined by the data layer.

To handle the translation between the two ID domains, you can use the `relay_id_translations`
option. With this, you can define a list of arguments that will be translated from Relay global IDs
to internal IDs.

For example, if you have a `Post` resource with an action to create a post associated with an
author:

```elixir
create :create do
  argument :author_id, :uuid

  # Do stuff with author_id
end
```

You can add this to the mutation connected to that action:

```elixir
mutations do
  create :create_post, :create do
    relay_id_translations [input: [author_id: :user]]
  end
end
```

## Using with Absinthe.Relay instead of Ash's relay type

Use the following option when calling `use AshGraphql`

```elixir
use AshGraphql, define_relay_types?: false
```
