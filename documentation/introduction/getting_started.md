# Getting Started

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

You will simply want to add some code to your router, like so:

You will also likely want to set up the "playground" for trying things out.

```elixir
scope "/" do
  forward "/gql", Absinthe.Plug, schema: YourSchema

  forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: YourSchema
          interface: :playground
end
```

If you started with `mix new ...` instead of `mix phx.new ...` and you want to
still use phoenix, the fastest path that way is typically to just create a new
phoenix application and copy your resources/config over.

### Setting context

Both queries and changesets support setting `context`, which can be used later on in
validations/authorization. Absinthe, the tool that backs AshGraphql, also has a `context` (easy to get the two confused). In order to provide context to the `Ash.Changeset` or `Ash.Query` that a given operation will perform, you'll need to set that absinthe context
Additionally, there is a special piece of context that Ash looks for to get the current user, or "actor" in Ash terms. This assign is called `:actor`. Ash does not declaratively manage things like authentication, because that tooling exists already in various forms for both Phoenix and Plug. An extension for authentication may very well exist at some point though.

 Here is an example of what your authorization plug might look like (see `Plug` for more information):

```elixir
defmodule MyApp.Plugs.Authentication do
  require Ash.Query

  def init(opts), do: opts

  def call(conn, params) do
    user_id = get_user_id(conn, params) 
    # how you go from `Plug.Conn` -> a user is all dependent on how your authentication
    # works 
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        %{"user_id" => firebase_id} = verify!(token)

        member =
          MilyAsh.Member
          |> Ash.Query.filter(firebase_id == ^firebase_id)
          |> MilyAsh.Api.read_one!()

        if member do
          Logger.info("User logged in #{member.id}")
        else
          Logger.info("No user existed with id #{firebase_id}")
        end

        Plug.Conn.assign(conn, :actor, member)

      _ ->
        Logger.info("No firebase context given")
        Plug.Conn.assign(conn, :actor, nil)
    end
  end

  def load_user(_, _), do: nil
  def load_groups(_, _), do: []

  def verify!(token) do
    {:ok, 200, _headers, ref} = :hackney.get(@cert_url)
    {:ok, body} = :hackney.body(ref)
    {:ok, %{"kid" => kid}} = Joken.peek_header(token)

    {true, %{fields: fields}, _} =
      body
      |> Jason.decode!()
      |> JOSE.JWK.from_firebase()
      |> Map.fetch!(kid)
      |> JOSE.JWT.verify(token)

    fields
  end
end

```