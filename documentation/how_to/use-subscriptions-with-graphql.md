# Using Subscriptions

The AshGraphql DSL does not currently support subscriptions. However, you can do this with Absinthe direclty, and use `AshGraphql.Subscription.query_for_subscription/3`. Here is an example of how you could do this for a subscription for a single record. This example could be extended to support lists of records as well.

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
