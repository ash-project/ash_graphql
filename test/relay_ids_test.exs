defmodule AshGraphql.RelayIdsTest do
  use ExUnit.Case, async: false

  alias AshGraphql.Test.RelayIds.{Api, Post, ResourceWithNoPrimaryKeyGet, Schema, User}

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

  describe "node interface and query" do
    test "allows retrieving resources" do
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

      document =
        """
          query Node($id: ID!) {
          node(id: $id) {
            __typename

            ... on User {
              name
            }

            ... on Post {
              text
            }
          }
        }
        """

      resp =
        document
        |> Absinthe.run(Schema,
          variables: %{
            "id" => post_relay_id
          }
        )

      assert {:ok, result} = resp

      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "node" => %{
                   "__typename" => "Post",
                   "text" => "foo"
                 }
               }
             } = result

      resp =
        document
        |> Absinthe.run(Schema,
          variables: %{
            "id" => user_relay_id
          }
        )

      assert {:ok, result} = resp

      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "node" => %{
                   "__typename" => "User",
                   "name" => "fred"
                 }
               }
             } = result
    end

    test "return an error for resources without a primary key get" do
      resource =
        ResourceWithNoPrimaryKeyGet
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      document =
        """
          query Node($id: ID!) {
          node(id: $id) {
            __typename

            ... on ResourceWithNoPrimaryKeyGet{
              name
            }
          }
        }
        """

      resource_relay_id = AshGraphql.Resource.encode_relay_id(resource)

      resp =
        document
        |> Absinthe.run(Schema,
          variables: %{
            "id" => resource_relay_id
          }
        )

      assert {:ok, result} = resp

      assert result[:errors] != nil
    end
  end

  describe "relay ID decoding" do
    test "round trips" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Fred"})
        |> Api.create!()

      user_id = user.id
      user_type = AshGraphql.Resource.Info.type(User)

      user_relay_id = AshGraphql.Resource.encode_relay_id(user)

      assert {:ok, %{type: ^user_type, id: ^user_id}} =
               AshGraphql.Resource.decode_relay_id(user_relay_id)
    end

    test "fails for invalid ids" do
      assert {:error, %Ash.Error.Invalid.InvalidPrimaryKey{}} =
               AshGraphql.Resource.decode_relay_id("notbase64")

      assert {:error, %Ash.Error.Invalid.InvalidPrimaryKey{}} =
               "non-existing-type:1234"
               |> Base.encode64()
               |> AshGraphql.Resource.decode_relay_id()

      assert {:error, %Ash.Error.Invalid.InvalidPrimaryKey{}} =
               "user"
               |> Base.encode64()
               |> AshGraphql.Resource.decode_relay_id()
    end
  end
end
