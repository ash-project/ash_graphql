defmodule AshGraphql.UpdateTest do
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
    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput) {
        updatePostConfirm(input: $input) {
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

    assert %{data: %{"updatePostConfirm" => %{"result" => nil, "errors" => [%{"message" => message}]}}} =
             result

    assert message =~ "Confirmation did not match value"
  end

  test "root level error" do
    Application.put_env(:ash, AshGraphql.Test.Api,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput) {
        updatePostConfirm(input: $input) {
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
end
