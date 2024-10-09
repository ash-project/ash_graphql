# Custom Queries & Mutations

You can define your own queries and mutations in your schema,
using Absinthe's tooling. See their docs for more.

If you want to return resource types defined by AshGraphql, however,
you will need to use `AshGraphql.load_fields/4` to ensure that any
requested fields are loaded.

For example:

```elixir
query do
  field :custom_get_post, :post do
    arg(:id, non_null(:id))

    resolve(fn %{id: post_id}, resolution ->
      with {:ok, post} when not is_nil(post) <- Ash.get(AshGraphql.Test.Post, post_id) do
        AshGraphql.load_fields(post, AshGraphql.Test.Post, resolution)
      end
    end)
  end
end
```
