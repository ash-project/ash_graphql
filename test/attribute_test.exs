defmodule AshGraphql.AttributeTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      try do
        AshGraphql.TestHelpers.stop_ets()
      rescue
        _ ->
          :ok
      end
    end)
  end

  test ":uuid arguments are mapped to ID type" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "SimpleCreatePostInput") {
          inputFields {
            name
            type {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    author_id_field =
      data["__type"]["inputFields"]
      |> Enum.find(fn field -> field["name"] == "authorId" end)

    assert author_id_field["type"]["name"] == "ID"
  end

  test "atom attribute with one_of constraints has enums automatically generated" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "PostVisibility") {
          enumValues {
            name
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert data["__type"]
  end

  test "atom attribute with one_of constraints uses enum for inputs" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "CreatePostInput") {
          inputFields {
            name
            type {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    visibility_field =
      data["__type"]["inputFields"]
      |> Enum.find(fn field -> field["name"] == "visibility" end)

    assert visibility_field["type"]["kind"] == "ENUM"
  end

  test "map attribute with field constraints get their own type" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "MapTypes") {
          fields {
            name
            type {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    fields = data["__type"]["fields"]

    attributes_field =
      fields
      |> Enum.find(fn field -> field["name"] == "attributes" end)

    values_field =
      fields
      |> Enum.find(fn field -> field["name"] == "values" end)

    assert attributes_field == %{
             "name" => "attributes",
             "type" => %{
               "kind" => "NON_NULL",
               "name" => nil,
               "ofType" => %{"kind" => "OBJECT", "name" => "MapTypesAttributes"}
             }
           }

    assert values_field == %{
             "name" => "values",
             "type" => %{"kind" => "OBJECT", "name" => "ConstrainedMap", "ofType" => nil}
           }
  end

  test "map attribute with field constraints use input objects for inputs" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "MapTypesAttributesInput") {
          inputFields {
            name
            type {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    foo_field =
      data["__type"]["inputFields"]
      |> Enum.find(fn field -> field["name"] == "foo" end)

    # non null field
    assert foo_field["type"]["kind"] == "NON_NULL"

    assert foo_field["type"]["ofType"]["kind"] == "SCALAR"
    assert foo_field["type"]["ofType"]["name"] == "String"

    bar_field =
      data["__type"]["inputFields"]
      |> Enum.find(fn field -> field["name"] == "bar" end)

    assert bar_field["type"]["kind"] == "SCALAR"
    assert bar_field["type"]["name"] == "Int"

    baz_field =
      data["__type"]["inputFields"]
      |> Enum.find(fn field -> field["name"] == "baz" end)

    assert baz_field["type"]["kind"] == "SCALAR"
    assert baz_field["type"]["name"] == "JsonString"
  end

  test "map arguments with constraints create an input object" do
    assert {:ok,
            %{
              data: %{
                "__type" => %{
                  "inputFields" => [
                    %{
                      "name" => "attributes",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "MapTypesAttributesInput",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "inlineValues",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "MapTypesInlineValuesInput",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "jsonMap",
                      "type" => %{
                        "kind" => "SCALAR",
                        "name" => "JsonString",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "values",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "ConstrainedMapInput",
                        "ofType" => nil
                      }
                    }
                  ]
                }
              }
            }} =
             """
             query {
               __type(name: "InlineUpdateMapTypesInput") {
                 inputFields {
                   name
                   type {
                     kind
                     name
                     ofType {
                       kind
                       name
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)
  end

  test "nested maps with constraints create types for nested maps" do
    assert {:ok,
            %{
              data: %{
                "__type" => %{
                  "fields" => [
                    %{
                      "name" => "bam",
                      "type" => %{
                        "kind" => "OBJECT",
                        "name" => "ConstrainedMapBam",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "baz",
                      "type" => %{"kind" => "SCALAR", "name" => "Int", "ofType" => nil}
                    },
                    %{
                      "name" => "fooBar",
                      "type" => %{
                        "kind" => "NON_NULL",
                        "name" => nil,
                        "ofType" => %{"kind" => "SCALAR", "name" => "String"}
                      }
                    }
                  ]
                }
              }
            }} =
             """
             query {
               __type(name: "ConstrainedMap") {
                 fields {
                   name
                   type {
                     kind
                     name
                     ofType {
                       kind
                       name
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok,
            %{
              data: %{
                "__type" => %{
                  "inputFields" => [
                    %{
                      "name" => "bam",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "ConstrainedMapBamInput",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "baz",
                      "type" => %{"kind" => "SCALAR", "name" => "Int", "ofType" => nil}
                    },
                    %{
                      "name" => "fooBar",
                      "type" => %{
                        "kind" => "NON_NULL",
                        "name" => nil,
                        "ofType" => %{"kind" => "SCALAR", "name" => "String"}
                      }
                    }
                  ]
                }
              }
            }} =
             """
             query {
               __type(name: "ConstrainedMapInput") {
                 inputFields {
                   name
                   type {
                     kind
                     name
                     ofType {
                       kind
                       name
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)
  end

  test "map subtypes with constraints used as arguments use the subtype input object" do
    assert {:ok,
            %{
              data: %{
                "__type" => %{
                  "inputFields" => [
                    %{
                      "name" => "attributes",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "MapTypesAttributesInput",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "jsonMap",
                      "type" => %{"kind" => "SCALAR", "name" => "JsonString", "ofType" => nil}
                    },
                    %{
                      "name" => "moduleValues",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "ConstrainedMapInput",
                        "ofType" => nil
                      }
                    },
                    %{
                      "name" => "values",
                      "type" => %{
                        "kind" => "INPUT_OBJECT",
                        "name" => "ConstrainedMapInput",
                        "ofType" => nil
                      }
                    }
                  ]
                }
              }
            }} =
             """
             query {
               __type(name: "ModuleUpdateMapTypesInput") {
                 inputFields {
                   name
                   type {
                     kind
                     name
                     ofType {
                       kind
                       name
                     }
                   }
                 }
               }
             }
             """
             |> Absinthe.run(AshGraphql.Test.Schema)
  end
end
