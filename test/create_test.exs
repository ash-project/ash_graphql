defmodule AshGraphql.CreateTest do
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

  test "a create with arguments works" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
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
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"createPost" => %{"result" => %{"text" => "foobar"}}}} = result
  end

  test "a create with a fragment works" do
    resp =
      """
      fragment comparisonFields on Post {
        text
      }
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            ...comparisonFields
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"createPost" => %{"result" => %{"text" => "foobar"}}}} = result
  end

  test "an upsert works" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.new(text: "foobar")
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      mutation CreatePost($input: UpsertPostInput) {
        upsertPost(input: $input) {
          result{
            text
            id
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "id" => post.id,
            "text" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    post_id = post.id

    assert %{data: %{"upsertPost" => %{"result" => %{"text" => "foobar", "id" => ^post_id}}}} =
             result
  end

  test "arguments are threaded properly" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
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
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{data: %{"createPost" => %{"result" => nil, "errors" => [%{"message" => message}]}}} =
             result

    assert message =~ "Confirmation did not match value"
  end

  test "custom input types are used" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            text
            foo{
              foo
              bar
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
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar",
            "foo" => %{
              "foo" => "foo",
              "bar" => "bar"
            }
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => %{"text" => "foobar", "foo" => %{"foo" => "foo", "bar" => "bar"}}
               }
             }
           } = result
  end

  test "standard enums are used" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            text
            statusEnum
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar",
            "statusEnum" => "OPEN"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => %{"text" => "foobar", "statusEnum" => "OPEN"}
               }
             }
           } = result
  end

  test "custom enums are used" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            text
            status
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar",
            "status" => "OPEN"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => %{"text" => "foobar", "status" => "OPEN"}
               }
             }
           } = result
  end
end
