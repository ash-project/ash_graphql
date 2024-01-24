defmodule AshGraphql.RelayIdsTest do
  use ExUnit.Case, async: false

  alias AshGraphql.Test.RelayIds.{Api, Post, Schema, User}

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "relay global ID" do
    test "can be used in get queries and is exposed correctly in relationships" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "fred"})
        |> Api.create!()

      post =
        Post
        |> Ash.Changeset.for_create(
          :create,
          %{
            author_id: user.id,
            text: "foo",
            published: true
          }
        )
        |> Api.create!()

      user_relay_id = AshGraphql.Resource.encode_relay_id(user)
      post_relay_id = AshGraphql.Resource.encode_relay_id(post)

      resp =
        """
          query GetPost($id: ID!) {
          getPost(id: $id) {
            text
            author {
              id
              name
            }
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{
            "id" => post_relay_id
          }
        )

      assert {:ok, result} = resp

      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "getPost" => %{
                   "text" => "foo",
                   "author" => %{"id" => ^user_relay_id, "name" => "fred"}
                 }
               }
             } = result
    end

    test "returns error on invalid ID" do
      resp =
        """
          query GetPost($id: ID!) {
          getPost(id: $id) {
            text
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{
            "id" => "invalid"
          }
        )

      assert {:ok, result} = resp
      assert [%{code: "invalid_primary_key"}] = result[:errors]
    end

    test "returns error on ID for wrong resource" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "fred"})
        |> Api.create!()

      user_relay_id = AshGraphql.Resource.encode_relay_id(user)

      resp =
        """
          query GetPost($id: ID!) {
          getPost(id: $id) {
            text
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{
            "id" => user_relay_id
          }
        )

      assert {:ok, result} = resp
      assert [%{code: "invalid_primary_key"}] = result[:errors]
    end
  end
end
