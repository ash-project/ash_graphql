defmodule AshGraphql.DestroyTest do
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

  test "a soft destroy works" do
    post = AshGraphql.Test.Api.create!(Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar"))

    resp =
      """
      mutation ArchivePost($id: ID) {
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

  test "a destroy with a configured read action and no identity works" do
    AshGraphql.Test.Api.create!(
      Ash.Changeset.new(AshGraphql.Test.Post, text: "foobar", best: true)
    )

    resp =
      """
      mutation DeleteBestPost {
        deleteBestPost {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"deleteBestPost" => %{"result" => %{"text" => "foobar"}}}} = result
  end

  test "destroying a non-existent record returns a not found error" do
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
          "id" => Ash.UUID.generate()
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"deletePost" => %{"errors" => [%{"message" => "could not be found"}]}}} =
             result
  end
end
