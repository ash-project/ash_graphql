defmodule AshGraphql.GenericActionsTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Api)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "generic action queries can be run" do
    resp =
      """
      query {
        postCount
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"postCount" => 0}} = result
  end

  test "generic action mutations can be run" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar"))

    resp =
      """
      mutation {
        randomPost {
          id
          comments{
            id
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    post_id = post.id

    assert %{data: %{"randomPost" => %{"id" => ^post_id, "comments" => []}}} = result
  end

  test "generic action mutations can be run with input" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar"))

    resp =
      """
      mutation {
        randomPost(input: {published: true}) {
          id
          comments{
            id
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    post_id = post.id

    assert %{data: %{"randomPost" => %{"id" => ^post_id, "comments" => []}}} = result
  end
end
