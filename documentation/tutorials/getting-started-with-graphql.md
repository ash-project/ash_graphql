# Getting Started With GraphQL

## Get familiar with Ash resources

If you haven't already, read the [Ash Getting Started Guide](https://hexdocs.pm/ash/get-started.html). This assumes that you already have resources set up, and only gives you the steps to _add_ AshGraphql to your resources/apis.

## Bring in the ash_graphql, and absinthe_plug dependencies

```elixir
def deps()
  [
    ...
    {:ash_graphql, "~> 0.22.4"},
    {:absinthe_plug, "~> x.x"}
  ]
end
```

Use `mix hex.info ash_graphql` and `mix hex.info absinthe_plug` to quickly find the latest versions.

## Add the API Extension

Add the following to your API module. If you don't have one, be sure to start with the [Ash Getting Started Guide](https://hexdocs.pm/ash/get-started.html).

```elixir
defmodule Helpdesk.Support do
  use Ash.Api, extensions: [
    AshGraphql.Api
  ]

  graphql do
    authorize? false # Defaults to `true`, use this to disable authorization for the entire API (you probably only want this while prototyping)
  end

  ... 
end
```

## Add graphql to your resources

Some example queries/mutations are shown below. If no queries/mutations are added, nothing will show up in the GraphQL API, so be sure to set one up if you want to try it out.

```elixir
defmodule Helpdesk.Support.Ticket. do
  use Ash.Resource,
    ...,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :ticket

    queries do
      # Examples

      # create a field called `get_ticket` that uses the `read` read action to fetch a single ticke
      get :get_ticket, :read 
      # create a field called `most_important_ticket` that uses the `most_important` read action to fetch a single record
      read_one :most_important_ticket, :most_important 

      # create a field called `list_tickets` that uses the `read` read action to fetch a list of tickets
      list :list_tickets, :read 
    end

    mutations do
      # Examples

      create :create_ticket, :create
      update :update_ticket, :update
      destroy :destroy_ticket, :destroy
    end
  end

  ...
end
```

## Add AshGraphql to your schema

If you don't have an absinthe schema, you can create one just for ash.

Define a `context/1` function, and call `AshGraphql.add_context/2` with the current context and your apis. Additionally, add the `Absinthe.Middleware.Dataloader` to your plugins, as shown below. If you're starting fresh, just copy the schema below and adjust the module name and api name.

```elixir
defmodule Helpdesk.Schema do
  use Absinthe.Schema

  @apis [Helpdesk.Support]

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
  init_opts: [schema: Helpdesk.Schema]

forward "/playground",
  to: Absinthe.Plug.GraphiQL,
  init_opts: [
    schema: Helpdesk.Schema,
    interface: :playground
  ]
```

### Using Phoenix

You will simply want to add some code to your router, like so.

You will also likely want to set up the "playground" for trying things out.

```elixir
scope "/" do
  forward "/gql", Absinthe.Plug, schema: Helpdesk.Schema

  forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: Helpdesk.Schema,
          interface: :playground
end
```

If you started with `mix new ...` instead of `mix phx.new ...` and you want to
still use phoenix, the fastest path that way is typically to just create a new
phoenix application and copy your resources/config over.

## What's next?

Topics:
- [GraphQL Generation](/documentation/topics/graphql-generation.md)

How Tos:
- [Authorize With GraphQL](/documentation/how_to/authorize-with-graphql.md)
- [Handle Errors](/documentation/how_to/handle-errors.md)
- [Use Enums with GraphQL](/documentation/how_to/use-enums-with-graphql.md)
- [Use JSON with GraphQL](/documentation/how_to/use-json-with-graphql.md)

[Monitoring](/documentation/monitoring.md)
