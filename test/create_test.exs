defmodule AshGraphql.CreateTest do
  use ExUnit.Case, async: true

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

    assert message =~ ~r/Value did not match confirmation/
  end
end
