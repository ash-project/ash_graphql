defmodule AliasTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "attribute alias works correctly for nullable attribute with built-in type" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true, score: 9.8)
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          content: text
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
    assert %{data: %{"getPost" => %{"content" => "foo"}}} = result
  end

  test "attribute alias works correctly for non-nullable attribute with built-in type" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true, score: 9.8)
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          text: requiredString
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
    assert %{data: %{"getPost" => %{"text" => "test"}}} = result
  end

  test "attribute alias works correctly for nullable attribute with custom type" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create,
        text: "foo",
        foo: %{bar: "baz"},
        published: true,
        score: 9.8
      )
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          bar: foo {
            bar
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
    assert %{data: %{"getPost" => %{"bar" => %{"bar" => "baz"}}}} = result
  end

  test "attribute alias works correctly for nullable attribute with embedded type" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create,
        text: "foo",
        embed: %{nested_embed: %{name: "test embed"}},
        published: true,
        score: 9.8
      )
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          embedded: embed {
            nested_embed {
              name
            }
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

    assert %{
             data: %{
               "getPost" => %{"embedded" => %{"nested_embed" => %{"name" => "test embed"}}}
             }
           } = result
  end

  test "calculation alias works correctly" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create,
        text: "foo",
        text1: "hello",
        text2: "world",
        published: true,
        score: 9.8
      )
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          content: full_text
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

    assert %{
             data: %{
               "getPost" => %{"content" => "helloworld"}
             }
           } = result
  end

  test "aggregate alias works correctly" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create,
        text: "foo",
        published: true,
        score: 9.8
      )
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          comments: commentCount
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

    assert %{
             data: %{
               "getPost" => %{"comments" => 0}
             }
           } = result
  end

  test "relationship alias works correctly" do
    author =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create, name: "My Name")
      |> Ash.create!()

    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create,
        text: "foo",
        published: true,
        score: 9.8,
        author_id: author.id
      )
      |> Ash.create!()

    resp =
      """
      query Post($id: ID!) {
        getPost(id: $id) {
          writer: author {
            name
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

    name = author.name

    assert %{
             data: %{
               "getPost" => %{"writer" => %{"name" => ^name}}
             }
           } = result
  end
end
