<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Custom Queries & Mutations

You can define your own queries and mutations in your schema,
using Absinthe's tooling. See their docs for more.

> ### You probably don't need this! {: .info}
>
> You can define generic actions in your resources which can return any
> type that you want, and those generic actions will automatically get
> all of the goodness of AshGraphql, with automatic data loading and
> type derivation, etc. See the [generic actions guide](/documentation/topics/generic-actions.md) for more.

## Using AshGraphql's types

If you want to return resource types defined by AshGraphql, however,
you will need to use `AshGraphql.load_fields_on_query/2` to ensure that any
requested fields are loaded.

For example:

```elixir
require Ash.Query

query do
  field :custom_get_post, :post do
    arg(:id, non_null(:id))

    resolve(fn %{id: post_id}, resolution ->
      MyApp.Blog.Post
      |> Ash.Query.filter(id == ^post_id)
      |> AshGraphql.load_fields_on_query(resolution)
      |> Ash.read_one(not_found_error?: true)
      |> AshGraphql.handle_errors(MyApp.Blog.Post, resolution)
    end)
  end
end
```

Alternatively, if you have records already that you need to load data on, use `AshGraphql.load_fields/3`:

```elixir
query do
  field :custom_get_post, :post do
    arg(:id, non_null(:id))

    resolve(fn %{id: post_id}, resolution ->
      with {:ok, post} when not is_nil(post) <- Ash.get(MyApp.Blog.Post, post_id) do
        AshGraphql.load_fields(post, MyApp.Blog.Post, resolution)
      end
      |> AshGraphql.handle_errors(MyApp.Blog.Post, resolution)
    end)
  end
end
```
