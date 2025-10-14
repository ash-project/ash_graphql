# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
end
