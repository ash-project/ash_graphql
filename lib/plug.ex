defmodule AshGraphql.Plug do
  @moduledoc """
  Automatically set up the GraphQL `actor` and `tenant`.

  Adding this plug to your pipeline will automatically set the `actor` and
  `tenant` if they were previously put there by `Ash.PlugHelpers.set_actor/2` or
  `Ash.PlugHelpers.set_tenant/2`.
  """

  @behaviour Plug
  alias Ash.PlugHelpers
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    actor = PlugHelpers.get_actor(conn)
    tenant = PlugHelpers.get_tenant(conn)

    absinthe = Map.get(conn.private, :absinthe, %{})

    context =
      absinthe
      |> Map.get(:context, %{})
      |> Map.merge(%{actor: actor, tenant: tenant})

    absinthe = Map.put(absinthe, :context, context)
    Conn.put_private(conn, :absinthe, absinthe)
  end
end
