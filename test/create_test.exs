defmodule AshGraphql.CreateTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
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

  test "a union type can be written to" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            simpleUnion {
              ... on PostSimpleUnionString {
                value
              }
              ... on PostSimpleUnionInt {
                value
              }
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
            "text1" => "foo",
            "simpleUnion" => %{
              "int" => 10
            }
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "simpleUnion" => %{
                     "value" => 10
                   }
                 }
               }
             }
           } = result
  end

  test "an embedded union type can be written to" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            embedUnion {
              ... on PostEmbedUnionFoo {
                value {
                  foo
                }
              }
              ... on PostEmbedUnionBar {
                value {
                  bar
                }
              }
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
            "text1" => "foo",
            "embedUnion" => %{
              "foo" => %{
                "foo" => "10"
              }
            }
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "embedUnion" => %{
                     "value" => %{
                       "foo" => "10"
                     }
                   }
                 }
               }
             }
           } = result
  end

  test "an embedded union new type can be written to" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            embedUnionNewType {
              ... on FooBarFoo {
                value {
                  foo
                }
              }
              ... on FooBarBar {
                value {
                  bar
                }
              }
            }
          }
          errors{
            message
            fields
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text1" => "foo",
            "embedUnionNewType" => %{
              "foo" => %{
                "foo" => "10"
              }
            }
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "embedUnionNewType" => %{
                     "value" => %{
                       "foo" => "10"
                     }
                   }
                 }
               }
             }
           } = result
  end

  test "a create can load a calculation without selecting the fields the calculation needs" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            fullText
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"text1" => "foo", "text2" => "bar"}}
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "fullText" => "foobar"
                 }
               }
             }
           } = result
  end

  test "a create can use custom input types" do
    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            integerAsStringInDomain
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"text1" => "foo", "integerAsStringInDomain" => "1"}}
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "integerAsStringInDomain" => "1"
                 }
               }
             }
           } = result
  end

  test "a create can load a calculation on a related belongs_to record" do
    author =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create, name: "My Name")
      |> Ash.create!()

    resp =
      """
      mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            fullText
            author {
              nameTwice
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"text1" => "foo", "text2" => "bar", "authorId" => author.id}}
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "simpleCreatePost" => %{
                 "result" => %{
                   "fullText" => "foobar",
                   "author" => %{
                     "nameTwice" => "My Name My Name"
                   }
                 }
               }
             }
           } = result
  end

  test "a create with a managed relationship works with many_to_many and [on_lookup: :relate, on_match: :relate]" do
    resp =
      """
      mutation CreatePostWithCommentsAndTags($input: CreatePostWithCommentsAndTagsInput!) {
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
      |> Ash.Changeset.for_create(:create, text: "foobar")
      |> Ash.create!()

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

    assert message =~ "confirmation did not match value"
  end

  defmodule ErrorHandler do
    def handle_error(error, _context) do
      %{error | message: "replaced!"}
    end
  end

  test "errors can be intercepted" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
      graphql: [
        error_handler: {ErrorHandler, :handle_error, []}
      ]
    )

    resp =
      """
      mutation CreatePost($input: CreatePostWithRequiredErrorInput) {
        createPostWithRequiredError(input: $input) {
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
          "input" => %{}
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createPostWithRequiredError" => %{
                 "result" => nil,
                 "errors" => [%{"message" => message}]
               }
             }
           } = result

    assert message =~ "replaced!"
  end

  test "root level error" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
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

    assert message =~ "confirmation did not match value"
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

  test "enum newtypes can be written to" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            text
            enumNewType
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
            "enumNewType" => "BIZ"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => %{"text" => "foobar", "enumNewType" => "BIZ"}
               }
             }
           } = result
  end

  test "string newtypes can be written to" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            stringNewType
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
            "stringNewType" => "hello world"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => %{"stringNewType" => "hello world"}
               }
             }
           } = result
  end

  test "string newtypes use their new constraints" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            stringNewType
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
            "stringNewType" => "goodbye world"
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPost" => %{
                 "result" => nil,
                 "errors" => [%{"message" => "must match the pattern ~r/hello/"}]
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
