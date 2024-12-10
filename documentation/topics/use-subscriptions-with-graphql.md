# Using Subscriptions

You can do this with Absinthe directly, and use
`AshGraphql.Subscription.query_for_subscription/3`. Here is an example of how
you could do this for a subscription for a single record. This example could be
extended to support lists of records as well.

```elixir
# in your absinthe schema file
subscription do
  field :field, :type_name do
    config(fn
      _args, %{context: %{current_user: %{id: user_id}}} ->
        {:ok, topic: user_id, context_id: "user/#{user_id}"}

      _args, _context ->
        {:error, :unauthorized}
    end)

    resolve(fn args, _, resolution ->
      # loads all the data you need
      AshGraphql.Subscription.query_for_subscription(
        YourResource,
        YourDomain,
        resolution
      )
      |> Ash.Query.filter(id == ^args.id)
      |> Ash.read(actor: resolution.context.current_user)
    end)
  end
end
```

## Subscription DSL (beta)

The subscription DSL is currently in beta and before using it you have to enable
them in your config.

> ### Subscription response order {: .warning}
>
> The order in which the subscription responses are sent to the client is not
> guaranteed to be the same as the order in which the mutations were executed.

```elixir
config :ash_graphql, :subscriptions, true
```

First you'll need to do some setup, follow the the
[setup guide](https://hexdocs.pm/absinthe/subscriptions.html#absinthe-phoenix-setup)
in the absinthe docs, but instead of using `Absinthe.Pheonix.Endpoint` use
`AshGraphql.Subscription.Endpoint`.

By default subscriptions are resolved synchronously as part of the mutation.
This means that a resolver is run for every subscriber that is not deduplicated.
If you have a lot of subscribers you can add the
`AshGraphql.Subscription.Batcher` to your supervision tree, which batches up
notifications and runs subscription resolution out-of-band.

```elixir
  @impl true
  def start(_type, _args) do
    children = [
      ...,
      {Absinthe.Subscription, MyAppWeb.Endpoint},
      AshGraphql.Subscription.Batcher
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

Afterwards, add an empty subscription block to your schema module.

```elixir
defmodule MyAppWeb.Schema do
  ...

  subscription do
  end
end
```

Now you can define subscriptions on your resource or domain

```elixir
defmodule MyApp.Resource do
  use Ash.Resource,
  data_layer: Ash.DataLayer.Ets,
  extensions: [AshGraphql.Resource]

  graphql do
    subscriptions do
      subscribe :resource_created do
        action_types :create
      end
    end
  end
end
```

For further Details checkout the DSL docs for
[resource](/documentation/dsls/DSL-AshGraphql.Resource.md#graphql-subscriptions)
and [domain](/documentation/dsls/DSL-AshGraphql.Domain.md#graphql-subscriptions)

### Deduplication

By default, Absinthe will deduplicate subscriptions based on the `context_id`.
We use the some of the context like actor and tenant to create a `context_id`
for you.

If you want to customize the deduplication you can do so by adding a actor
function to your subscription. This function will be called with the actor that
subscribes and you can return a more generic actor, this way you can have one
actor for multiple users, which will lead to less resolver executions.

```elixir
defmodule MyApp.Resource do
  use Ash.Resource,
  data_layer: Ash.DataLayer.Ets,
  extensions: [AshGraphql.Resource]

  graphql do
    subscriptions do
      subscribe :resource_created do
        action_types :create
        actor fn actor ->
          if check_actor(actor) do
            %{id: "your generic actor", ...}
          else
            actor
          end
        end
      end
    end
  end
end
```
