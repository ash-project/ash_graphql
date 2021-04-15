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

  test "reading relationships works, without selecting the id field" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true)
      |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Comment
    |> Ash.Changeset.for_create(:create, %{text: "stuff"})
    |> Ash.Changeset.force_change_attribute(:post_id, post.id)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          text
          comments{
            text
          }
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

    assert %{data: %{"postLibrary" => [%{"text" => "foo", "comments" => [%{"text" => "stuff"}]}]}} =
             result
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

  test "a read with custom types works" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create,
      text: "bar",
      published: true,
      foo: %{foo: "foo", bar: "bar"}
    )
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          text
          staticCalculation
          foo{
            foo
            bar
          }
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

    assert %{
             data: %{
               "postLibrary" => [
                 %{
                   "text" => "bar",
                   "staticCalculation" => "static",
                   "foo" => %{"foo" => "foo", "bar" => "bar"}
                 }
               ]
             }
           } = result
  end

  test "a read without an argument works" do
    user =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create,
        name: "My Name"
      )
      |> AshGraphql.Test.Api.create!()

    doc = """
    query CurrentUser {
      currentUser {
        name
      }
    }
    """

    assert {:ok,
            %{
              data: %{
                "currentUser" => %{
                  "name" => "My Name"
                }
              }
            }} == Absinthe.run(doc, AshGraphql.Test.Schema, context: %{actor: user})
  end
end
