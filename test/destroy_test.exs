defmodule AshGraphql.DestroyTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  # Helper function to create a post with comments for aggregate testing
  defp create_post_with_comments(comment_count) do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "test post")
      |> Ash.create!()

    # Create the specified number of comments
    for i <- 1..comment_count do
      AshGraphql.Test.Comment
      |> Ash.Changeset.for_create(:create, text: "comment #{i}", post_id: post.id)
      |> Ash.create!()
    end

    # Reload post to ensure relationships are properly loaded
    AshGraphql.Test.Post
    |> Ash.get!(post.id)
  end

  test "a destroy works" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar")
      |> Ash.create!()

    resp =
      """
      mutation DeletePost($id: ID!) {
        deletePost(id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"deletePost" => %{"result" => %{"text" => "foobar"}}}} = result
    refute Ash.get!(AshGraphql.Test.Post, post.id, error?: false)
  end

  test "a soft destroy works" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar")
      |> Ash.create!()

    resp =
      """
      mutation ArchivePost($id: ID!) {
        deletePost(id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"deletePost" => %{"result" => %{"text" => "foobar"}}}} = result
  end

  test "a destroy with a configured read action and no identity works" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
    |> Ash.create!()

    resp =
      """
      mutation DeleteBestPost {
        deleteBestPost {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"deleteBestPost" => %{"result" => %{"text" => "foobar"}}}} = result
  end

  test "a destroy with an error" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

    resp =
      """
      mutation DeleteWithError($id: ID!) {
        deletePostWithError(id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "deletePostWithError" => %{
                 "errors" => [%{"message" => "could not be found"}],
                 "result" => nil
               }
             }
           } == result
  end

  test "destroying a non-existent record returns a not found error" do
    resp =
      """
      mutation DeletePost($id: ID!) {
        deletePost(id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => Ash.UUID.generate()
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"deletePost" => %{"errors" => [%{"message" => "could not be found"}]}}} =
             result
  end

  test "root level error on destroy" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

    resp =
      """
      mutation DeletePost($id: ID!) {
        deletePostWithError(id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )

    assert {:ok, result} = resp

    assert %{errors: [%{message: "could not be found"}]} = result
  end

  test "destroy properly allows policy authorized destroys" do
    user =
      AshGraphql.Test.User |> Ash.Changeset.for_create(:create) |> Ash.create!(authorize?: false)

    resp =
      """
      mutation DeleteCurrentUser {
        deleteCurrentUser {
          result{
            name
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        context: %{
          actor: user
        }
      )

    assert {:ok,
            %{
              data: %{
                "deleteCurrentUser" => %{"errors" => [], "result" => %{"name" => nil}}
              }
            }} = resp
  end

  test "destroy mutation with aggregate reproduces NotLoaded serialization error" do
    # Create a post with comments to make the aggregate meaningful
    post = create_post_with_comments(3)

    # This test demonstrates the bug: attempting to serialize the result will fail
    # because commentCount returns %Ash.NotLoaded{} instead of the actual count
    # Expected behavior would be to return the comment count (3) before deletion
    # or handle the aggregate gracefully

    assert_raise Absinthe.SerializationError, ~r/Could not serialize term #Ash\.NotLoaded/, fn ->
      """
      mutation DeletePost($id: ID!) {
        deletePost(id: $id) {
          result {
            text
            commentCount
          }
          errors {
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )
    end
  end

  test "destroy mutation with aggregate - zero comments case" do
    # Test the edge case with zero comments
    post = create_post_with_comments(0)

    # This should also demonstrate the NotLoaded issue even with zero comments
    assert_raise Absinthe.SerializationError, ~r/Could not serialize term #Ash\.NotLoaded/, fn ->
      """
      mutation DeletePost($id: ID!) {
        deletePost(id: $id) {
          result {
            text
            commentCount
          }
          errors {
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id
        }
      )
    end
  end
end
