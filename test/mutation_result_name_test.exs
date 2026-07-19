# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MutationResultNameTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "mutation result_name" do
    test "default create mutations still expose result" do
      resp =
        """
        mutation SimpleCreatePost($input: SimpleCreatePostInput) {
          simpleCreatePost(input: $input) {
            result {
              text
              comments { text }
            }
            errors { message }
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
                     "text" => "foobar",
                     "comments" => []
                   }
                 }
               }
             } = result
    end

    test "configured result_name exposes a custom result key with nested selection" do
      resp =
        """
        mutation CreatePostWithResultName($input: CreatePostWithResultNameInput) {
          createPostWithResultName(input: $input) {
            post {
              text
              comments { text }
            }
            errors { message }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema,
          variables: %{"input" => %{"text" => "custom key"}}
        )

      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "createPostWithResultName" => %{
                   "post" => %{
                     "text" => "custom key",
                     "comments" => []
                   }
                 }
               }
             } = result
    end

    test "configured result_name resolves payload when resource has a public result attribute" do
      resp =
        """
        mutation CreatePostWithResultName($input: CreatePostWithResultNameInput) {
          createPostWithResultName(input: $input) {
            post {
              text
              result
            }
            errors { message }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema,
          variables: %{"input" => %{"text" => "body", "result" => "resource-result"}}
        )

      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "createPostWithResultName" => %{
                   "post" => %{
                     "text" => "body",
                     "result" => "resource-result"
                   }
                 }
               }
             } = result
    end
  end
end
