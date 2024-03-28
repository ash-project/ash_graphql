defmodule AshGraphql.PlugTest do
  @moduledoc false
  use ExUnit.Case, async: false
  require Ash.Query
  import Plug.Conn

  @moduletag capture_log: true

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  defmodule Pipeline do
    @moduledoc false
    use Plug.Router
    plug(Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason)
    plug(AshGraphql.Plug)
    plug(:match)
    plug(:dispatch)
    forward("/", to: Absinthe.Plug, init_opts: [schema: AshGraphql.Test.Schema])
  end

  test "when the actor is set, the current user returns the correct value" do
    user =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create, %{name: "My Name"})
      |> Ash.create!()

    resp =
      """
      query {
        currentUser {
          id
          name
        }
      }
      """
      |> conn()
      |> Ash.PlugHelpers.set_actor(user)
      |> run()

    assert resp["data"]["currentUser"]["id"] == user.id
    assert resp["data"]["currentUser"]["name"] == user.name
  end

  test "when the actor is not set, the current user return nil" do
    resp =
      """
      query {
        currentUser {
          id
          name
        }
      }
      """
      |> conn()
      |> run()

    refute resp["data"]["currentUser"]
  end

  test "when the tenant is set, the the multi tenant tag is correct" do
    tenant = "Marty McFly"

    tag =
      AshGraphql.Test.MultitenantTag
      |> Ash.Changeset.for_create(:create, [name: "1985"], tenant: tenant)
      |> Ash.create!()

    resp =
      """
      query MultitenantTag($id: ID!) {
        getMultitenantTag(id: $id) {
          name
        }
      }
      """
      |> conn(%{id: tag.id})
      |> Ash.PlugHelpers.set_tenant(tenant)
      |> run()

    assert resp["data"]["getMultitenantTag"]["name"] == "1985"
  end

  test "when the tenant is not set, the multi tennant tag is nil" do
    resp =
      """
      query MultitenantTag($id: ID!) {
        getMultitenantTag(id: $id) {
          name
        }
      }
      """
      |> conn(%{id: Ecto.UUID.generate()})
      |> run()

    refute resp["data"]["getMultitenantTag"]
  end

  def conn(query, variables \\ %{}) do
    :post
    |> Plug.Test.conn("/", %{query: query, variables: variables})
    |> put_req_header("content-type", "application/json")
  end

  def run(conn) do
    conn
    |> Pipeline.call([])
    |> Map.fetch!(:resp_body)
    |> Jason.decode!()
  end
end
