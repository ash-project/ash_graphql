defmodule AshGraphql.ReadTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      try do
        ETS.Set.delete(ETS.Set.wrap_existing!(AshGraphql.Test.Post))
      rescue
        _ ->
          :ok
      end
    end)
  end

  test "a read with arguments works" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foo", published: true)
    |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", published: false)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          text
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "published" => true
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"postLibrary" => [%{"text" => "foo"}]}} = result
  end

  test "a read with a loaded field works" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", published: true)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          text
          staticCalculation
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "published" => true
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"postLibrary" => [%{"text" => "bar", "staticCalculation" => "static"}]}} =
             result
  end
end
