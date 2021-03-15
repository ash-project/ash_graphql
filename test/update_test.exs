defmodule AshGraphql.UpdateTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      try do
        ETS.Set.delete(ETS.Set.wrap_existing!(AshGraphql.Test.Post))
        ETS.Set.delete(ETS.Set.wrap_existing!(AshGraphql.Test.Comment))
      rescue
        _ ->
          :ok
      end
    end)
  end

  test "an update works" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar"))

    resp =
      """
      mutation UpdatePost($id: ID, $input: UpdatePostInput) {
        updatePost(id: $id, input: $input) {
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
          "id" => post.id,
          "input" => %{
            "text" => "barbuz"
          }
        }
      )

    assert {:ok, %{data: %{"updatePost" => %{"errors" => [], "result" => %{"text" => "barbuz"}}}}} =
             resp
  end

  test "an update can add related items" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post))
    comment = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Comment))

    resp =
      """
      mutation UpdatePost($id: ID, $input: UpdatePostInput) {
        updatePost(id: $id, input: $input) {
          result{
            comments{
              id
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "comments" => %{
              "add" => [comment.id]
            }
          }
        }
      )

    comment_id = comment.id

    assert {:ok,
            %{
              data: %{
                "updatePost" => %{
                  "errors" => [],
                  "result" => %{"comments" => [%{"id" => ^comment_id}]}
                }
              }
            }} = resp
  end

  test "an update can remove related items" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post))

    comment =
      AshGraphql.Test.Comment
      |> Ash.Changeset.new()
      |> Ash.Changeset.replace_relationship(:post, post)
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      mutation UpdatePost($id: ID, $input: UpdatePostInput) {
        updatePost(id: $id, input: $input) {
          result{
            comments{
              id
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "comments" => %{
              "remove" => [comment.id]
            }
          }
        }
      )

    assert {:ok,
            %{
              data: %{
                "updatePost" => %{
                  "errors" => [],
                  "result" => %{"comments" => []}
                }
              }
            }} = resp
  end

  test "an update can replace related items" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post))

    AshGraphql.Test.Comment
    |> Ash.Changeset.new()
    |> Ash.Changeset.replace_relationship(:post, post)
    |> AshGraphql.Test.Api.create!()

    other_comment =
      AshGraphql.Test.Comment
      |> Ash.Changeset.new()
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      mutation UpdatePost($id: ID, $input: UpdatePostInput) {
        updatePost(id: $id, input: $input) {
          result{
            comments{
              id
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "comments" => %{
              "replace" => [other_comment.id]
            }
          }
        }
      )

    other_comment_id = other_comment.id

    assert {:ok,
            %{
              data: %{
                "updatePost" => %{
                  "errors" => [],
                  "result" => %{"comments" => [%{"id" => ^other_comment_id}]}
                }
              }
            }} = resp
  end
end
