defmodule AshGraphql.ReadTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
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

  test "union fields works correctly" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foo", published: true, simple_union: 10)
    |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", published: true, simple_union: "foo")
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query postLibrary {
        postLibrary {
          text
          simpleUnion {
            ... on PostSimpleUnionString {
              value
            }
            ... on PostSimpleUnionInt {
              value
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok,
            %{
              data: %{
                "postLibrary" => [
                  %{"simpleUnion" => %{"value" => value1}},
                  %{"simpleUnion" => %{"value" => value2}}
                ]
              }
            }} = resp

    assert Enum.sort([10, "foo"]) == Enum.sort([value1, value2])
  end

  test "metadata fields are rendered" do
    AshGraphql.Test.User
    |> Ash.Changeset.for_create(:create,
      name: "My Name"
    )
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query CurrentUserWithMetadata {
        currentUserWithMetadata {
          bar
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"currentUserWithMetadata" => %{"bar" => "bar"}}} = result
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

  test "a read with custom set types works" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foo", integer_as_string_in_api: 1, published: true)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary {
        postLibrary {
          text
          integerAsStringInApi
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"postLibrary" => [%{"integerAsStringInApi" => "1"}]}} = result
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

  test "the same relationship can be fetched with different parameters" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true)
      |> AshGraphql.Test.Api.create!()

    for _ <- 0..1 do
      AshGraphql.Test.Comment
      |> Ash.Changeset.for_create(:create, %{text: "stuff"})
      |> Ash.Changeset.force_change_attribute(:post_id, post.id)
      |> AshGraphql.Test.Api.create!()
    end

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          text
          foo: comments(limit: 1){
            text
          }
          bar: comments(limit: 2){
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

    assert %{
             data: %{
               "postLibrary" => [
                 %{
                   "text" => "foo",
                   "foo" => [%{"text" => "stuff"}],
                   "bar" => [%{"text" => "stuff"}, %{"text" => "stuff"}]
                 }
               ]
             }
           } = result
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

  test "the same calculation can be loaded twice with different arguments via aliases" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", text1: "1", text2: "2", published: true)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published) {
          foo: text1And2(separator: "foo")
          bar: text1And2(separator: "bar")
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{data: %{"postLibrary" => [%{"foo" => "1foo2", "bar" => "1bar2"}]}} = result
  end

  test "the same calculation can be sorted on twice with different arguments via aliases" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", text1: "1", text2: "2", published: true)
    |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", text1: "1", text2: "2", published: true)
    |> AshGraphql.Test.Api.create!()

    resp =
      """
      query PostLibrary($published: Boolean) {
        postLibrary(published: $published, sort: [{field: TEXT1_AND2, order: DESC, text1And2Input: {separator: "a"}}, {field: TEXT1_AND2, order: DESC, text1And2Input: {separator: "b"}}]) {
          a: text1And2(separator: "a")
          b: text1And2(separator: "b")
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "postLibrary" => [%{"a" => "1a2", "b" => "1b2"}, %{"a" => "1a2", "b" => "1b2"}]
             }
           } = result
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

  test "get requests against non-encoded primary key fields accept both fields and display both fields" do
    record =
      AshGraphql.Test.CompositePrimaryKeyNotEncoded
      |> Ash.Changeset.for_create(:create, %{})
      |> AshGraphql.Test.Api.create!()

    resp =
      """
      query GetCompositePrimaryKeyNotEncoded($first: ID!, $second: ID!) {
        getCompositePrimaryKeyNotEncoded(first: $first, second: $second) {
          first
          second
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "first" => record.first,
          "second" => record.second
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    first = record.first
    second = record.second

    assert %{
             data: %{
               "getCompositePrimaryKeyNotEncoded" => %{"first" => ^first, "second" => ^second}
             }
           } = result
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

  test "manual relationships can be read" do
    tag =
      AshGraphql.Test.Tag
      |> Ash.Changeset.for_create(
        :create,
        name: "My Tag"
      )
      |> AshGraphql.Test.Api.create!()

    post_1 =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foo", published: true)
      |> Ash.Changeset.manage_relationship(
        :tags,
        [tag],
        on_no_match: {:create, :create_action},
        on_lookup: :relate
      )
      |> AshGraphql.Test.Api.create!()

    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "bar", published: true)
    |> Ash.Changeset.manage_relationship(
      :tags,
      [tag],
      on_no_match: {:create, :create_action},
      on_lookup: :relate
    )
    |> AshGraphql.Test.Api.create!()

    doc = """
    query ($id: ID!) {
      getPost(id: $id) {
        text
        relatedPosts {
          text
        }
      }
    }
    """

    assert {:ok,
            %{
              data: %{
                "getPost" => %{
                  "relatedPosts" => [%{"text" => "bar"}],
                  "text" => "foo"
                }
              }
            }} ==
             Absinthe.run(doc, AshGraphql.Test.Schema, variables: %{"id" => post_1.id})
  end
end
