defmodule AshGraphql.DestroyTest do
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

  test "a destroy works" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar"))

    resp =
      """
      mutation DeletePost($id: ID) {
        deletePost(id: $id) {
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
          "id" => post.id
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"deletePost" => %{"result" => %{"text" => "foobar"}}}} = result
  end
end
