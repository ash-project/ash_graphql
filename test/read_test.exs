defmodule AshGraphql.ReadTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGraphql.Test.Post)
    end)
  end

  test "float fields works correctly" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foo", published: true, score: 9.8)
    |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", published: true, score: 9.85)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostScore($score: Float) {
        postScore(score: $score) {
          text
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "score" => 9.8
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"postScore" => [%{"text" => "foo"}]}} = result
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

  test "complexity is calculated for relationships" do
    query = """
    query PostLibrary {
      paginatedPosts(limit: 2) {
        results{
          text
          comments(limit: 2){
            text
            post {
              comments(limit: 2) {
                text
                post {
                  text
                }
              }
            }
          }
        }
      }
    }
    """

    query
    |> Absinthe.run(AshGraphql.Test.Schema,
      analyze_complexity: true,
      max_complexity: 36
    )

    resp =
      query
      |> Absinthe.run(AshGraphql.Test.Schema,
        analyze_complexity: true,
        max_complexity: 35
      )

    assert {:ok, %{errors: errors}} = resp

    assert errors |> Enum.map(& &1.message) |> Enum.sort() == [
             "Field paginatedPosts is too complex: complexity is 36 and maximum is 35",
             "Operation PostLibrary is too complex: complexity is 36 and maximum is 35"
           ]

    # assert
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

  test "a read with a non-id primary key fills in the id field" do
    record =
      AshGraphql.Test.NonIdPrimaryKey
      |> Ash.Changeset.for_create(:create, %{})
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      query GetNonIdPrimaryKey($id: ID!) {
        getNonIdPrimaryKey(id: $id) {
          id
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => record.other
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    id = record.other

    assert %{data: %{"getNonIdPrimaryKey" => %{"id" => ^id}}} = result
  end

  test "a read with a composite primary key fills in the id field" do
    record =
      AshGraphql.Test.CompositePrimaryKey
      |> Ash.Changeset.for_create(:create, %{})
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      query GetCompositePrimaryKey($id: ID!) {
        getCompositePrimaryKey(id: $id) {
          id
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => AshGraphql.Resource.encode_primary_key(record)
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    id = AshGraphql.Resource.encode_primary_key(record)

    assert %{data: %{"getCompositePrimaryKey" => %{"id" => ^id}}} = result
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

  test "a multitenant object can be read if tenant is set" do
    tenant = "Some Tenant"

    tag =
      AshGraphql.Test.MultitenantTag
      |> Ash.Changeset.for_create(
        :create,
        [name: "My Tag1"],
        tenant: tenant
      )
      |> AshGraphql.Test.Api.create!()

    doc = """
    query MultitenantTag($id: ID!) {
      getMultitenantTag(id: $id) {
        name
      }
    }
    """

    assert {:ok,
            %{
              data: %{
                "getMultitenantTag" => %{
                  "name" => "My Tag1"
                }
              }
            }} ==
             Absinthe.run(doc, AshGraphql.Test.Schema,
               context: %{tenant: tenant},
               variables: %{"id" => tag.id}
             )
  end

  test "a multitenant relation can be read if tenant is set" do
    tenant = "Some Tenant"

    tag =
      AshGraphql.Test.MultitenantTag
      |> Ash.Changeset.for_create(
        :create,
        [name: "My Tag"],
        tenant: tenant
      )
      |> AshGraphql.Test.Api.create!()

    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true)
      |> Ash.Changeset.manage_relationship(
        :multitenant_tags,
        [tag],
        on_no_match: {:create, :create_action},
        on_lookup: :relate
      )
      |> AshGraphql.Test.Api.create!()

    doc = """
    query MultitenantPostTag($id: ID!) {
      getPost(id: $id) {
        text
        published
        multitenantTags {
          name
        }
      }
    }
    """

    assert {:ok,
            %{
              data: %{
                "getPost" => %{
                  "published" => true,
                  "text" => "foo",
                  "multitenantTags" => [
                    %{
                      "name" => "My Tag"
                    }
                  ]
                }
              }
            }} ==
             Absinthe.run(doc, AshGraphql.Test.Schema,
               context: %{tenant: tenant},
               variables: %{"id" => post.id}
             )
  end
end
