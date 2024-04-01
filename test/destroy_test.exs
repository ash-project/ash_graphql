defmodule AshGraphql.DestroyTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
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
end
