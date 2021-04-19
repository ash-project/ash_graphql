defmodule AshGraphql.UpdateTest do
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
end
