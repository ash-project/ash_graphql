# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.AshGraphqlInstallTest do
  use ExUnit.Case

  import Igniter.Test

  setup_all do
    igniter =
      phx_test_project()
      |> Igniter.compose_task("ash_graphql.install", ["--yes"])

    [igniter: igniter]
  end

  test "creates the graphql schema", %{igniter: igniter} do
    assert_creates(igniter, "lib/test_web/graphql_schema.ex", ~S'''
    defmodule TestWeb.GraphqlSchema do
      use Absinthe.Schema

      use AshGraphql,
        domains: []

      import_types(Absinthe.Plug.Types)

      query do
        # Custom Absinthe queries can be placed here
        @desc """
        Hello! This is a sample query to verify that AshGraphql has been set up correctly.
        Remove me once you have a query of your own!
        """
        field :say_hello, :string do
          resolve(fn _, _, _ ->
            {:ok, "Hello from AshGraphql!"}
          end)
        end
      end

      mutation do
        # Custom Absinthe mutations can be placed here
      end

      subscription do
        # Custom Absinthe subscriptions can be placed here
      end
    end
    ''')
  end

  test "adds ash_graphql to the formatter", %{igniter: igniter} do
    assert_has_patch(igniter, ".formatter.exs", ~S'''
      |[
    - |  import_deps: [:ecto, :ecto_sql, :phoenix],
    + |  import_deps: [:ash_graphql, :absinthe, :ecto, :ecto_sql, :phoenix],
      |  subdirectories: ["priv/*/migrations"],
    - |  plugins: [Phoenix.LiveView.HTMLFormatter],
    + |  plugins: [Absinthe.Formatter, Phoenix.LiveView.HTMLFormatter],
      |  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
      |]
    ''')
  end

  test "updates config", %{igniter: igniter} do
    assert_has_patch(igniter, "config/config.exs", ~S'''
    + |config :spark,
    + |  formatter: [
    + |    "Ash.Resource": [section_order: [:graphql]],
    + |    "Ash.Domain": [section_order: [:graphql]]
    + |  ]
    + |
    + |config :ash_graphql, authorize_update_destroy_with_error?: true
    + |
    ''')
  end

  test "updates appliaction", %{igniter: igniter} do
    assert_has_patch(igniter, "lib/test/application.ex", ~S'''
      |      # {Test.Worker, arg},
      |      # Start to serve requests, typically the last entry
    - |      TestWeb.Endpoint
    + |      TestWeb.Endpoint,
    + |      {Absinthe.Subscription, TestWeb.Endpoint},
    + |      AshGraphql.Subscription.Batcher
      |    ]
      |
    ''')
  end

  test "creates the socket for subscriptions", %{igniter: igniter} do
    assert_creates(igniter, "lib/test_web/graphql_socket.ex", ~S'''
    defmodule TestWeb.GraphqlSocket do
      use Phoenix.Socket

      use Absinthe.Phoenix.Socket,
        schema: TestWeb.GraphqlSchema

      @impl true
      def connect(_params, socket, _connect_info) do
        {:ok, socket}
      end

      @impl true
      def id(_socket), do: nil
    end
    ''')
  end

  test "adds the socket and parser to the endpoint", %{igniter: igniter} do
    igniter
    |> assert_has_patch("lib/test_web/endpoint.ex", ~S'''
    + |  socket("/ws/gql", TestWeb.GraphqlSocket, websocket: true, longpoll: true)
    ''')
    |> assert_has_patch("lib/test_web/endpoint.ex", ~S'''
    + |  use Absinthe.Phoenix.Endpoint
    ''')
  end

  test "adds the gql routes in the router", %{igniter: igniter} do
    assert_has_patch(igniter, "lib/test_web/router.ex", ~S'''
     ...|
        |  use TestWeb, :router
        |
      + |  pipeline :graphql do
      + |    plug(AshGraphql.Plug)
      + |  end
      + |
        |  pipeline :browser do
        |    plug(:accepts, ["html"])
     ...|
        |  end
        |
      + |  scope "/gql" do
      + |    pipe_through([:graphql])
      + |
      + |    forward("/playground", Absinthe.Plug.GraphiQL,
      + |      schema: Module.concat(["TestWeb.GraphqlSchema"]),
      + |      socket: Module.concat(["TestWeb.GraphqlSocket"]),
      + |      interface: :simple
      + |    )
      + |
      + |    forward("/", Absinthe.Plug, schema: Module.concat(["TestWeb.GraphqlSchema"]))
      + |  end
      + |
        |  scope "/", TestWeb do
        |    pipe_through(:browser)
    ''')
  end
end
