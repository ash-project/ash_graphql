# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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

  test "can list ranked comments, testing newType of map with Resource inside" do
    [
      "a",
      "b",
      "c"
    ]
    |> Enum.each(fn text ->
      Ash.Seed.seed!(%AshGraphql.Test.Comment{text: text})
    end)

    assert {:ok, %{data: %{"listRankedComments" => data}}} =
             """
             query {
               listRankedComments {
                 rank
                 comment {
                   text
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)

    assert List.first(data)["rank"] < List.last(data)["rank"]
  end

  test "can use argument in filter and sort on calculated field" do
    [
      "a",
      "b",
      "c"
    ]
    |> Enum.each(fn text ->
      Ash.Seed.seed!(%AshGraphql.Test.Comment{text: text})
    end)

    Ash.read!(AshGraphql.Test.Comment, load: [:timestamp, arg_returned: [seconds: 10]])
    |> Enum.each(fn %{arg_returned: arg_returned} ->
      assert 10 = arg_returned
    end)

    assert {:ok, %{data: %{"listComments" => comments}}} =
             """
             query {
               listComments(
               filter: {argReturned: {input: {seconds: 10}}}
               sort: {argReturnedInput: {seconds: 10}, field: ARG_RETURNED, order: ASC_NULLS_LAST}
               ) {
                 text
                 argReturned(seconds: 10)
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)

    Enum.each(comments, fn %{"arg_returned" => arg_returned} ->
      assert 10 = arg_returned
    end)
  end

  test "array type with non-null constraint on items generates correct GraphQL type" do
    assert {:ok, %{data: data}} =
             """
             query {
               __type(name: "CategoryHierarchy") {
                 name
                 kind
                 fields {
                   name
                   type {
                     name
                     kind
                     ofType {
                       name
                       kind
                       ofType {
                         name
                         kind
                         ofType {
                           name
                           kind
                         }
                       }
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)

    category_hierarchy = data["__type"]
    assert category_hierarchy["name"] == "CategoryHierarchy"
    assert category_hierarchy["kind"] == "OBJECT"

    categories_field = Enum.find(category_hierarchy["fields"], &(&1["name"] == "categories"))
    assert categories_field != nil

    assert categories_field["type"]["kind"] == "NON_NULL"
    assert categories_field["type"]["ofType"]["kind"] == "LIST"
    assert categories_field["type"]["ofType"]["ofType"]["kind"] == "NON_NULL"
    assert categories_field["type"]["ofType"]["ofType"]["ofType"]["name"] == "Category"
    assert categories_field["type"]["ofType"]["ofType"]["ofType"]["kind"] == "OBJECT"

    assert {:ok, %{data: category_data}} =
             """
             query {
               __type(name: "Category") {
                 name
                 kind
                 fields {
                   name
                   type {
                     name
                     kind
                     ofType {
                       name
                       kind
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)

    category_type = category_data["__type"]
    assert category_type["name"] == "Category"
    assert category_type["kind"] == "OBJECT"

    name_field = Enum.find(category_type["fields"], &(&1["name"] == "name"))
    assert name_field != nil

    assert name_field["type"]["kind"] == "NON_NULL"
    assert name_field["type"]["ofType"]["name"] == "String"
    assert name_field["type"]["ofType"]["kind"] == "SCALAR"
  end

  test "can create resource from typed struct and read it back as typed struct" do
    create_mutation = """
    mutation {
      createFromTypedStruct(input:{
        personData: {
          name: "John Doe",
          age: 30,
          email: "john.doe@example.com"
        }
      })
    }
    """

    assert {:ok, %{data: %{"createFromTypedStruct" => resource_id}}} =
             Absinthe.run(create_mutation, AshGraphql.Test.Schema)

    get_mutation = """
    mutation {
      getAsTypedStruct(input:{
        id: "#{resource_id}"
      }) {
        name
        age
        email
      }
    }
    """

    assert {:ok, %{data: %{"getAsTypedStruct" => typed_struct_result}}} =
             Absinthe.run(get_mutation, AshGraphql.Test.Schema)

    assert typed_struct_result["name"] == "John Doe"
    assert typed_struct_result["age"] == 30
    assert typed_struct_result["email"] == "john.doe@example.com"
  end
end
