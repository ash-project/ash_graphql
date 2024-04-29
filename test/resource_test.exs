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
end
