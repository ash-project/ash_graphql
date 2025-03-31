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
