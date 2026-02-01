# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.DestroyTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  defp create_post_with_comments(comment_count) do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "test post")
      |> Ash.create!()

    if comment_count > 0 do
      for i <- 1..comment_count do
        AshGraphql.Test.Comment
        |> Ash.Changeset.for_create(:create, text: "comment #{i}", post_id: post.id)
        |> Ash.create!()
      end
    end

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

  test "destroy mutation returns aggregates" do
    post = create_post_with_comments(2)

    resp =
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

    assert {:ok,
            %{
              data: %{
                "deletePost" => %{
                  "result" => %{
                    "text" => "test post",
                    "commentCount" => 2
                  },
                  "errors" => []
                }
              }
            }} = resp
  end

  test "destroy mutation returns zero aggregates" do
    post = create_post_with_comments(0)

    resp =
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

    assert {:ok,
            %{
              data: %{
                "deletePost" => %{
                  "result" => %{
                    "text" => "test post",
                    "commentCount" => 0
                  },
                  "errors" => []
                }
              }
            }} = resp
  end
end
