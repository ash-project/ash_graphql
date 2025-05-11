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

  test "generic action queries can request errors in the response" do
    resp =
      """
      query {
        postCountWithErrors {
          result
          errors {
            message
            fields
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema, context: %{actor: %{id: "an-actor"}})

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"postCountWithErrors" => %{"result" => 0, "errors" => []}}} = result
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
        randomPost(input: {published: false}) {
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

  describe "generic action with args" do
    setup do
      post =
        AshGraphql.Test.Post
        |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
        |> Ash.create!()

      run = fn args ->
        """
        mutation {
          randomPostWithArg#{args} {
            id
            comments{
              id
            }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema)
      end

      expect_post = fn args ->
        post_id = post.id

        assert {:ok, result} = run.(args)
        assert %{data: %{"randomPostWithArg" => %{"id" => ^post_id, "comments" => []}}} = result
      end

      expect_nil = fn args ->
        assert {:ok, result} = run.(args)
        assert %{data: %{"randomPostWithArg" => nil}} = result
      end

      expect_error = fn args, message ->
        assert {:ok, result} = run.(args)
        assert %{errors: [%{message: ^message}]} = result
      end

      [
        expect_post: expect_post,
        expect_nil: expect_nil,
        expect_error: expect_error
      ]
    end

    test "defines and uses an argument", %{expect_post: expect_post, expect_nil: expect_nil} do
      expect_post.("(published: false)")
      expect_nil.("(published: true)")
    end

    test "does not require optional arguments", %{expect_post: expect_post} do
      expect_post.("")
    end

    test "works together with input object", %{expect_post: expect_post} do
      expect_post.("(published: false, input: {best: true})")
    end

    test "does not define input field for an argument", %{expect_error: expect_error} do
      expect_error.(
        "(input: {published: false})",
        "Argument \"input\" has invalid value {published: false}.\nIn field \"published\": Unknown field."
      )
    end
  end
end
