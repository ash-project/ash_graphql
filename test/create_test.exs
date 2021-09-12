defmodule AshGraphql.CreateTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      try do
        Ash.DataLayer.Ets.stop(AshGraphql.Test.Post)
        Ash.DataLayer.Ets.stop(AshGraphql.Test.Comment)
      rescue
        _ ->
          :ok
      end
    end)
  end

  test "metadata is in the result" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text
            comments(sort:{field:TEXT}){
              text
            }
          }
          metadata{
            foo
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"text" => "foobar"}}
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "text" => "foobar"
                 },
                 "metadata" => %{
                   "foo" => "bar"
                 }
               }
             }
           } = result
  end

  test "a create with a managed relationship works" do
    resp =
      """
      mutation CreatePostWithComments($input: CreatePostWithCommentsInput) {
        createPostWithComments(input: $input) {
          result{
            text
            comments(sort:{field:TEXT}){
              text
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
            "comments" => [
              %{"text" => "foobar"},
              %{"text" => "barfoo"}
            ]
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPostWithComments" => %{
                 "result" => %{
                   "text" => "foobar",
                   "comments" => [%{"text" => "barfoo"}, %{"text" => "foobar"}]
                 }
               }
             }
           } = result
  end

  test "a create with a managed relationship works with many_to_many and [on_lookup: :relate, on_match: :relate]" do
    resp =
      """
      mutation CreatePostWithCommentsAndTags($input: CreatePostWithCommentsAndTagsInput) {
        createPostWithCommentsAndTags(input: $input) {
          result{
            text
            comments(sort:{field:TEXT}){
              text
            }
            tags(sort:{field:NAME}){
              name
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
            "comments" => [
              %{"text" => "foobar"},
              %{"text" => "barfoo"}
            ],
            "tags" => [%{"name" => "test"}, %{"name" => "tag"}]
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPostWithCommentsAndTags" => %{
                 "result" => %{
                   "text" => "foobar",
                   "comments" => [%{"text" => "barfoo"}, %{"text" => "foobar"}],
                   "tags" => [%{"name" => "tag"}, %{"name" => "test"}]
                 }
               }
             }
           } = result
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

  test "root level error" do
    Application.put_env(:ash, AshGraphql.Test.Api,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

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

    assert %{errors: [%{message: message}]} = result

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
