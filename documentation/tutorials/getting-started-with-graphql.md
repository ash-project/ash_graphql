# Getting Started With GraphQL

## Get familiar with Ash resources

If you haven't already, read the [Ash Getting Started Guide](https://hexdocs.pm/ash/get-started.html). This assumes that you already have resources set up, and only gives you the steps to _add_ AshGraphql to your resources/domains.

## Installation

<!-- tabs-open -->

### Using Igniter (recommended)

```elixir
mix igniter.install ash_graphql
```

### Manual

#### Bring in the `ash_graphql` dependency

```elixir
def deps()
  [
    ...
    {:ash_graphql, "~> 1.5.0"}
  ]
end
```

#### Setting up your schema

If you don't have an absinthe schema, you can create one just for ash.
Replace `helpdesk` in the examples with your own application name.

See [the SDL file guide](/documentation/topics/sdl-file.md) for more information on using the SDL file,
or remove the `generate_sdl_file` option to skip generating it on calls to `mix ash.codegen`.

in `lib/helpdesk/schema.ex`

```elixir
defmodule Helpdesk.GraphqlSchema do
  use Absinthe.Schema

  # Add your domains here
  use AshGraphql,
    domains: [Your.Domains]

  query do
    # Custom absinthe queries can be placed here
    @desc "Remove me once you have a query of your own!"
    field :remove_me, :string do
      resolve fn _, _, _ ->
        {:ok, "Remove me!"}
      end
    end
  end

  mutation do
    # Custom absinthe mutations can be placed here
  end
end
```

#### Connect your schema

##### Using Phoenix

Add the following code to your Phoenix router. It's useful to set up the Absinthe playground for trying things out, but it's optional.

```elixir
pipeline :graphql do
  plug AshGraphql.Plug
end

scope "/gql" do
  pipe_through [:graphql]

  forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: Module.concat(["Helpdesk.GraphqlSchema"]),
          interface: :playground

  forward "/",
    Absinthe.Plug,
    schema: Module.concat(["Helpdesk.GraphqlSchema"])
end
```

> ### Whats up with `Module.concat/1`? {: .info}
>
> This `Module.concat/1` prevents a [compile-time dependency](https://dashbit.co/blog/speeding-up-re-compilation-of-elixir-projects) from this router module to the schema module. It is an implementation detail of how `forward/2` works that you end up with a compile-time dependency on the schema, but there is no need for this dependency, and that dependency can have _drastic_ impacts on your compile times in certain scenarios.

If you started with `mix new ...` instead of `mix phx.new ...` and you want to
still use Phoenix, the fastest path that way is typically to just create a new
Phoenix application and copy your resources/config over.

##### Using Plug

If you are unfamiliar with how plug works, this [guide](https://elixirschool.com/en/lessons/specifics/plug/#dependencies)
will be helpful for understanding it. It also guides you through adding plug to your application.

Then you can use a `Plug.Router` and [forward](https://hexdocs.pm/plug/Plug.Router.html#forward/2) to your plugs similar to how it is done for phoenix:

```elixir
plug AshGraphql.Plug

forward "/gql",
  to: Absinthe.Plug,
  init_opts: [schema: Module.concat(["Helpdesk.GraphqlSchema"])]

forward "/playground",
  to: Absinthe.Plug.GraphiQL,
  init_opts: [
    schema: Module.concat(["Helpdesk.GraphqlSchema"]),
    interface: :playground
  ]
```

For information on why we are using `Module.concat/1`, see the note above in the Phoenix section.

<!-- tabs-close -->

## Select domains to show in your GraphQL

In the `use AshGraphql` call in your schema, you specify which domains you want to expose in your GraphQL API. Add any domains that will have `AshGraphql` queries/mutations to the `domains` list. For example:

```elixir
use AshGraphql, domains: [Your.Domain1, Your.Domain2]
```

## Adding Queries and Mutations

Some example queries/mutations are shown below. If no queries/mutations are added, nothing will show up in the GraphQL API, so be sure to set one up if you want to try it out.

### Queries & Mutations on the Resource

Here we show queries and mutations being added to the resource, but you can also define them on the _domain_. See below for an equivalent definition

```elixir
defmodule Helpdesk.Support.Ticket do
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

### Queries & Mutations on the Domain

```elixir
defmodule Helpdesk.Support.Ticket do
  use Ash.Resource,
    ...,
    extensions: [
      AshGraphql.Resource
    ]

  # The resource still determines its type, and any other resource/type-based
  # configuration
  graphql do
    type :ticket
  end

  ...
end

defmodule Helpdesk.Support do
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  ...
  graphql do
    # equivalent queries and mutations, but the first argument
    # is the resource because the domain can define queries for
    # any of its resources
    queries do
      get Helpdesk.Support.Ticket, :get_ticket, :read
      read_one Helpdesk.Support.Ticket, :most_important_ticket, :most_important
      list Helpdesk.Support.Ticket, :list_tickets, :read
    end

    mutations do
      create Helpdesk.Support.Ticket, :create_ticket, :create
      update Helpdesk.Support.Ticket, :update_ticket, :update
      destroy Helpdesk.Support.Ticket, :destroy_ticket, :destroy
    end
end
```

## What's next?

Topics:

- [GraphQL Generation](/documentation/topics/graphql-generation.md)

How Tos:

- [Authorize With GraphQL](/documentation/topics/authorize-with-graphql.md)
- [Handle Errors](/documentation/topics/handle-errors.md)
- [Use Enums with GraphQL](/documentation/topics/use-enums-with-graphql.md)
- [Use JSON with GraphQL](/documentation/topics/use-json-with-graphql.md)
