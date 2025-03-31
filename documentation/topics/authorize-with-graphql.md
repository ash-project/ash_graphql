# Authorize with GraphQL

AshGraphql uses three special keys in the `absinthe` context:

- `:actor` - the current actor, to be used for authorization/preparations/changes
- `:tenant` - a tenant when using [multitenancy](https://hexdocs.pm/ash/multitenancy.html).
- `:ash_context` - a map of arbitrary context to be passed into the changeset/query. Accessible via `changeset.context` and `query.context`

By default, `authorize?` in the domain is set to true. To disable authorization for a given domain in graphql, use:

```elixir
graphql do
  authorize? false
end
```

If you are doing authorization, you'll need to provide an `actor`.

### Using AshAuthentication

If you have not yet installed AshAuthentication, you can install it with igniter:

```bash
# installs ash_authentication & ash_authentication_phoenix
mix igniter.install ash_authentication_phoenix 
```

If you've already set up `AshGraphql` before adding `AshAuthentication`, you will 
just need to make sure that your `:graphql` scope in your router looks like this:

```elixir
pipeline :graphql do
  plug :load_from_bearer
  plug :set_actor, :user
  plug AshGraphql.Plug
end
```

### Using Something Else

To set the `actor` for authorization, you'll need to add an `actor` key to the
absinthe context. Typically, you would have a plug that fetches the current user and uses `Ash.PlugHelpers.set_actor/2` to set the actor in the `conn` (likewise with `Ash.PlugHelpers.set_tenant/2`).

Just add `AshGraphql.Plug` somewhere _after_ that in the pipeline and the your
GraphQL APIs will have the correct authorization.

```elixir
defmodule MyAppWeb.Router do
  pipeline :api do
    # ...
    plug :get_actor_from_token
    plug AshGraphql.Plug
  end

  scope "/" do
    forward "/gql", Absinthe.Plug, schema: YourSchema

    forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: YourSchema,
          interface: :playground
  end

  def get_actor_from_token(conn, _opts) do
     with ["" <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- MyApp.Guardian.resource_from_token(token) do
      conn
      |> set_actor(user)
    else
    _ -> conn
    end
  end
end
```

## Policy Breakdowns

By default, unauthorized requests simply return `forbidden` in the message. If you prefer to show policy breakdowns in your GraphQL errors, you can set the config option:

```elixir
config :ash_graphql, :policies, show_policy_breakdowns?: true
```

```json
{
  "data": {
    "attendanceRecords": null
  },
  "errors": [
    {
      "code": "forbidden",
      "fields": [],
      "locations": [
        {
          "column": 3,
          "line": 2
        }
      ],
      "message": "MyApp.Authentication.User.read\n\n\n\n\nPolicy Breakdown\n  Policy | ⛔:\n    forbid unless: actor is active | ✓ | ⬇    \n    authorize if: actor is Executive | ✘ | ⬇",
      "path": ["attendanceRecords"],
      "short_message": "forbidden",
      "vars": {}
    }
  ]
}
```

Be careful, as this can be an attack vector in some systems (i.e "here is exactly what you need to make true to do what you want to do").

## Field Policies

Field policies in AshGraphql work by producing a `null` value for any forbidden field, as well as an error in the errors list.

> ### nullability {: .warning}
>
> Any fields with field policies on them should be nullable. If they are not nullable, the _parent_ object will also be `null` (and considered in an error state), because `null` is not a valid type for that field.

To make fields as nullable even if it is not nullable by its definition, use the `nullable_fields` option.

```elixir
graphql do
  type :post

  nullable_fields [:foo, :bar, :baz]
end
```
