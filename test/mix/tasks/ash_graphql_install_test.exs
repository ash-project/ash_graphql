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
     1 1   |[
     2   - |  import_deps: [:ecto, :ecto_sql, :phoenix],
       2 + |  import_deps: [:ash_graphql, :absinthe, :ecto, :ecto_sql, :phoenix],
     3 3   |  subdirectories: ["priv/*/migrations"],
     4   - |  plugins: [Phoenix.LiveView.HTMLFormatter],
       4 + |  plugins: [Absinthe.Formatter, Phoenix.LiveView.HTMLFormatter],
     5 5   |  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
     6 6   |]
    ''')
  end

  test "updates config", %{igniter: igniter} do
    assert_has_patch(igniter, "config/config.exs", ~S'''
      8  8   |import Config
      9  9   |
        10 + |config :spark,
        11 + |  formatter: [
        12 + |    "Ash.Resource": [section_order: [:graphql]],
        13 + |    "Ash.Domain": [section_order: [:graphql]]
        14 + |  ]
        15 + |
     10 16   |config :test,
     11 17   |  ecto_repos: [Test.Repo],
    ''')
  end

  test "updates appliaction", %{igniter: igniter} do
    assert_has_patch(igniter, "lib/test/application.ex", ~S'''
     18 18   |      # {Test.Worker, arg},
     19 19   |      # Start to serve requests, typically the last entry
     20    - |      TestWeb.Endpoint
        20 + |      TestWeb.Endpoint,
        21 + |      {Absinthe.Subscription, TestWeb.Endpoint},
        22 + |      AshGraphql.Subscription.Batcher
     21 23   |    ]
     22 24   |
    ''')
  end

  test "creates the socket for subscriptions", %{igniter: igniter} do
    assert_creates(igniter, "lib/test_web/graphql_socket.ex", ~S'''
    defmodule TestWeb.GraphqlSocket do
      use Phoenix.Socket

      use Absinthe.Phoenix.Socket,
        schema: TestWeb.GraphqlSchema

      @otp_app :test

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
    assert_has_patch(igniter, "lib/test_web/endpoint.ex", ~S'''
          ...|
     17 17   |  )
     18 18   |
        19 + |  socket("/ws/gql", TestWeb.GraphqlSocket,
        20 + |    websocket: true,
        21 + |    longpoll: true
        22 + |  )
        23 + |
     19 24   |  # Serve at "/" the static files from "priv/static" directory.
     20 25   |  #
          ...|
     46 51   |
     47 52   |  plug(Plug.Parsers,
     48    - |    parsers: [:urlencoded, :multipart, :json],
        53 + |    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
     49 54   |    pass: ["*/*"],
     50 55   |    json_decoder: Phoenix.json_library()

    ''')
  end

  test "adds the gql routes in the router", %{igniter: igniter} do
    assert_has_patch(igniter, "lib/test_web/router.ex", ~S'''
          ...|
      2  2   |  use TestWeb, :router
      3  3   |
         4 + |  pipeline :graphql do
         5 + |    plug(AshGraphql.Plug)
         6 + |  end
         7 + |
      4  8   |  pipeline :browser do
      5  9   |    plug(:accepts, ["html"])
          ...|
     15 19   |  end
     16 20   |
        21 + |  scope "/gql" do
        22 + |    pipe_through([:graphql])
        23 + |
        24 + |    forward(
        25 + |      "/playground",
        26 + |      Absinthe.Plug.GraphiQL,
        27 + |      schema: Module.concat(["TestWeb.GraphqlSchema"]),
        28 + |      socket: Module.concat(["TestWeb.GraphqlSocket"]),
        29 + |      interface: :playground
        30 + |    )
        31 + |
        32 + |    forward(
        33 + |      "/",
        34 + |      Absinthe.Plug,
        35 + |      schema: Module.concat(["TestWeb.GraphqlSchema"])
        36 + |    )
        37 + |  end
        38 + |
     17 39   |  scope "/", TestWeb do
     18 40   |    pipe_through(:browser)
          ...|
    ''')
  end
end
