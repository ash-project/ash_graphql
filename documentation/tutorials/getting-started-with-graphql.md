# Getting Started With GraphQL

## Get familiar with Ash resources

If you haven't already, read the getting started guide for Ash. This assumes that you already have resources set up, and only gives you the steps to _add_ AshGraphql to your resources/apis.

## Bring in the ash_graphql, and absinthe_plug dependencies

```elixir
def deps()
  [
    ...
    {:ash_graphql, "~> x.x"}
    {:absinthe_plug, "~> x.x"},
  ]
end
```

Use `mix hex.info ash_graphql` and `mix hex.info absinthe_plug` to quickly find the latest versions.

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

    queries do
      get :get_post, :read # <- create a field called `get_post` that uses the `read` read action to fetch a single post
      read_one :current_user, :current_user # <- create a field called `current_user` that uses the `current_user` read action to fetch a single record
      list :list_posts, :read # <- create a field called `list_posts` that uses the `read` read action to fetch a list of posts
    end

    mutations do
      # And so on
      create :create_post, :create
      update :update_post, :update
      destroy :destroy_post, :destroy
    end
  end
end
```

## Add AshGraphql to your schema

If you don't have an absinthe schema, you can create one just for ash.

Define a `context/1` function, and call `AshGraphql.add_context/2` with the current context and your apis. Additionally, add the `Absinthe.Middleware.Dataloader` to your plugins, as shown below. If you're starting fresh, just copy the schema below and adjust the module name and api name.

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  @apis [MyApp.Api]

  use AshGraphql, apis: @apis

  # The query and mutation blocks is where you can add custom absinthe code
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

## Connect your schema

### Using Plug

If you are unfamiliar with how plug works, this [guide](https://elixirschool.com/en/lessons/specifics/plug/#dependencies) will be helpful for understanding it. It also guides you through
adding plug to your application.

Then you can use a `Plug.Router` and [forward](https://hexdocs.pm/plug/Plug.Router.html#forward/2) to your plugs similar to how it is done for phoenix:

```elixir
forward "/gql",
  to: Absinthe.Plug,
  init_opts: [schema: YourSchema]

forward "/playground",
  to: Absinthe.Plug.GraphiQL,
  init_opts: [
    schema: YourSchema,
    interface: :playground
  ]
```

### Using Phoenix

You will simply want to add some code to your router, like so.

You will also likely want to set up the "playground" for trying things out.

```elixir
scope "/" do
  forward "/gql", Absinthe.Plug, schema: YourSchema

  forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: YourSchema,
          interface: :playground
end
```

If you started with `mix new ...` instead of `mix phx.new ...` and you want to
still use phoenix, the fastest path that way is typically to just create a new
phoenix application and copy your resources/config over.
