# Authorization and Context

AshGraphql uses two special keys in the `absinthe` context:

* `:actor` - the current actor, to be used for authorization/preparations/changes
* `:ash_context` - a map of arbitrary context to be passed into the changeset/query. Accessible via `changeset.context` and `query.context`

By default, `authorize?` in the api is set to true. To disable authorization for a given API in graphql, use:

```elixir
graphql do
  authorize? false
end
```

If you are doing authorization, you'll need to provide an `actor`.
To set the `actor` for authorization, you'll need to add an `actor` key to the absinthe context. Typically, you would have a plug that fetches the current user, and in that plug you could set the absinthe context. For example:

```elixir
defmodule MyAppWeb.UserPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _) do
    case build_context(conn) do
      {:ok, context} ->
        put_private(conn, :absinthe, %{context: context})

      _ ->
        conn
    end
  end

  defp build_context(conn) do
    with ["" <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- MyApp.Guardian.resource_from_token(token) do
         # ash_context allows you to pass arbitrary data down into the changeset/query context
         # This can be accessed at `changeset.context` or `query.context`.
      {:ok, %{actor: user, ash_context: %{some: :data}}}
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
      "path": [
        "attendanceRecords"
      ],
      "short_message": "forbidden",
      "vars": {}
    }
  ]
}
```

Be careful, as this can be an attack vector in some systems (i.e "here is exactly what you need to make true to do what you want to do").
