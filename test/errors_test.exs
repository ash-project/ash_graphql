defmodule AshGraphql.ErrorsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  setup do
    on_exit(fn ->
      Application.delete_env(:ash, AshGraphql.Test.Api)

      try do
        Ash.DataLayer.Ets.stop(AshGraphql.Test.Post)
        Ash.DataLayer.Ets.stop(AshGraphql.Test.Comment)
      rescue
        _ ->
          :ok
      end
    end)
  end

  test "errors can be configured to be shown in the root" do
    Application.put_env(:ash, AshGraphql.Test.Api, graphql: [root_level_errors?: true])

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

    assert %{data: %{"createPost" => nil}, errors: [%{message: message}]} = result

    assert message =~ "Confirmation did not match value"
  end

  test "raised errors are by default not shown" do
    assert capture_log(fn ->
             resp =
               """
               mutation CreatePostWithError($input: CreatePostWithErrorInput) {
                 createPostWithError(input: $input) {
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
                     "text" => "foobar"
                   }
                 }
               )

             assert {:ok, result} = resp

             assert %{data: %{"createPostWithError" => nil}, errors: [%{message: message}]} =
                      result

             assert message =~ "Something went wrong."
           end) =~ "Exception raised while resolving query"
  end

  test "raised errors can be configured to be shown" do
    Application.put_env(:ash, AshGraphql.Test.Api, graphql: [show_raised_errors?: true])

    resp =
      """
      mutation CreatePostWithError($input: CreatePostWithErrorInput) {
        createPostWithError(input: $input) {
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
            "text" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createPostWithError" => %{"errors" => [%{"message" => message}]}
             }
           } = result

    assert message =~ "is required"
  end

  test "showing raised errors alongside root errors shows raised errors in the root" do
    Application.put_env(:ash, AshGraphql.Test.Api,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

    resp =
      """
      mutation CreatePostWithError($input: CreatePostWithErrorInput) {
        createPostWithError(input: $input) {
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
            "text" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createPostWithError" => nil
             },
             errors: [
               %{message: message}
             ]
           } = result

    assert message =~ "is required"
  end
end
