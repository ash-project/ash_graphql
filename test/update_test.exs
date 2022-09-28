defmodule AshGraphql.UpdateTest do
  use ExUnit.Case, async: false

  setup do
    Application.delete_env(:ash_graphql, AshGraphql.Test.Api)

    on_exit(fn ->
      try do
        AshGraphql.TestHelpers.stop_ets()
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

  test "an update with a configured read action and no identity works" do
    post =
      AshGraphql.Test.Api.create!(
        Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar", best: true)
      )

    resp =
      """
      mutation UpdateBestPost($input: UpdateBestPostInput) {
        updateBestPost(input: $input) {
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

    assert {:ok,
            %{data: %{"updateBestPost" => %{"errors" => [], "result" => %{"text" => "barbuz"}}}}} =
             resp
  end

  test "arguments are threaded properly" do
    post =
      AshGraphql.Test.Api.create!(
        Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar", best: true)
      )

    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput, $id: ID) {
        updatePostConfirm(input: $input, id: $id) {
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
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "updatePostConfirm" => %{"result" => nil, "errors" => [%{"message" => message}]}
             }
           } = result

    assert message =~ "Confirmation did not match value"
  end

  test "root level error" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Api,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

    post =
      AshGraphql.Test.Api.create!(
        Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar", best: true)
      )

    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput, $id: ID) {
        updatePostConfirm(input: $input, id: $id) {
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
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{errors: [%{message: message}]} = result

    assert message =~ "Confirmation did not match value"
  end
end
