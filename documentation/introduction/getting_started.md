# Getting Started

## Get familiar with Ash resources

If you haven't already, read the getting started guide for Ash. This assumes that you already have resources set up, and only gives you the steps to _add_ AshGraphql to your resources/apis.

## Add the API Extension

```elixir
defmodule MyApi do
  use Ash.Api, extensions: [
    AshGraphql.Api
  ]

  graphql do
    authorize? false # Defaults to `true`, use this to disable authorization for the entire API (you probably only want this while prototyping)
  end
end
```

## Add graphql to your resources

```elixir
defmodule Post do
  use Ash.Resource,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :post

    fields [:name, :count_of_comments, :comments] # <- a list of all of the attributes/relationships/aggregates to include in the graphql API

    queries do
      get :get_post, :default # <- create a field called `get_post` that uses the `default` read action to fetch a single post
      list :list_posts, :default # <- create a field called `list_posts` that uses the `default` read action to fetch a list of posts
    end

    mutations do
      # And so on
      create :create_post, :default
      update :update_post, :default
      destroy :destroy_post, :default
    end
  end
end
```

## Add AshGraphql to your schema

If you don't have an absinthe schema, you can create one just for ash

If you don't have any queries or mutations in your schema, you may
need to add empty query and mutation blocks. If you have no mutations,
don't add an empty mutations block, same for queries. Additionally,
define a `context/1` function, and call `AshGraphql.add_context/2` with
the current context and your apis. Additionally, add the `Absinthe.Middleware.Dataloader`
to your plugins, as shown below. If you're starting fresh, just copy the schema below and
adjust the module name and api name.

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  @apis [MyApp.Api]

  use AshGraphql, apis: @apis

  query do
  end

  mutation do
  end

  def context(ctx) do
    AshGraphql.add_context(ctx, @apis)
  end

  def plugins() do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end

```
