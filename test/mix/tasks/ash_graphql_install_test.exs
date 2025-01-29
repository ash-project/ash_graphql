defmodule Mix.Tasks.AshGraphqlInstallTest do
  use ExUnit.Case

  import Igniter.Test

  setup do
    igniter =
      phx_test_project()
      |> Igniter.compose_task("ash_graphql.install", ["--yes"])

    [igniter: igniter]
  end

  test "ash_graphql.install", %{igniter: igniter} do
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
end
