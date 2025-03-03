defmodule AshGraphql.ResourceTest do
  use ExUnit.Case

  test "object generated according to generate_object?" do
    assert %Absinthe.Type.Object{
             identifier: :user
           } = Absinthe.Schema.lookup_type(AshGraphql.Test.Schema, :user)

    assert nil == Absinthe.Schema.lookup_type(AshGraphql.Test.Schema, :no_object)
  end

  test "resource with no type can execute generic queries" do
    resp =
      """
      query NoObjectCount {
        noObjectCount
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)
    assert %{data: %{"noObjectCount" => [1, 2, 3, 4, 5]}} = result
  end

  test "queries can be created with custom descriptions" do
    {:ok, %{data: data}} =
      """
      query {
        __schema {
          queryType {
            name
            fields {
              name
              description
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    get_post_with_custom_description_query =
      data["__schema"]["queryType"]["fields"]
      |> Enum.find(fn field -> field["name"] == "getPostWithCustomDescription" end)

    assert get_post_with_custom_description_query["description"] ==
             "A custom description"
  end

  test "mutations can be created with custom descriptions" do
    {:ok, %{data: data}} =
      """
      query {
        __schema {
          mutationType {
            name
            fields {
              name
              description
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    create_post_with_custom_description_mutation =
      data["__schema"]["mutationType"]["fields"]
      |> Enum.find(fn field -> field["name"] == "createPostWithCustomDescription" end)

    assert create_post_with_custom_description_mutation["description"] ==
             "Another custom description"
  end

  test "arguments with the same name can generate different types for different mutations" do
    {:ok, %{data: with_foo}} =
      """
      query {
        __type(name: "CreatePostBarWithFooInput") {
          name
          inputFields {
            name
            type {
              name
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    {:ok, %{data: with_baz}} =
      """
      query {
        __type(name: "CreatePostBarWithBazInput") {
          name
          inputFields {
            name
            type {
              name
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    bar_with_foo =
      with_foo["__type"]["inputFields"]
      |> Enum.find(&(&1["name"] == "bar"))

    bar_with_baz =
      with_baz["__type"]["inputFields"]
      |> Enum.find(&(&1["name"] == "bar"))

    assert bar_with_foo["type"] == %{"name" => "BarWithFoo"}
    assert bar_with_baz["type"] == %{"name" => "BarWithBaz"}
  end

  test "arguments can have their types overriden" do
    {:ok, %{data: with_foo}} =
      """
      query {
        __type(name: "CreatePostBarWithFooWithMapInput") {
          name
          inputFields {
            name
            type {
              name
              kind
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    bar_with_foo =
      with_foo["__type"]["inputFields"]
      |> Enum.find(&(&1["name"] == "bar"))

    assert bar_with_foo["type"] == %{"name" => "BarWithFoo", "kind" => "INPUT_OBJECT"}
  end

  test "can create resource with type inside type" do
    assert {:ok, %{data: %{"createTypeInsideType" => true}}} =
             """
             mutation {
               createTypeInsideType(input:{
                 typeWithType: {
                   inner_type: {
                     some: "foo",
                     stuff: "bar"
                   },
                   another_field: "baz"
                 }
               })
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)
  end
end
