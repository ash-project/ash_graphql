# Authorization

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
      {:ok, %{current_user: user}}
    end
  end
end
```
