defmodule AshGraphql.GenericActionsTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

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
      |> Absinthe.run(AshGraphql.Test.Schema, context: %{actor: %{id: "an-actor"}})

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"postCount" => 0}} = result
  end

  test "generic action that have policies return forbidden if no actor is present" do
    resp =
      """
      query {
        postCount
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    assert Map.has_key?(result, :errors)

    assert %{
             data: nil,
             errors: [
               %{
                 code: "forbidden",
                 message: "forbidden",
                 path: ["postCount"],
                 fields: [],
                 vars: %{},
                 locations: [%{line: 2, column: 3}],
                 short_message: "forbidden"
               }
             ]
           } == result
  end

  test "generic action mutations can be run" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

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
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

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
