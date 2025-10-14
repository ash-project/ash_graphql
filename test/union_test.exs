# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.UnionTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "union has all member types including custom types" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "Uniontype") {
          name
          possibleTypes {
            name
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    possible_type_names = Enum.map(data["__type"]["possibleTypes"], & &1["name"]) |> Enum.sort()

    assert [
             "UniontypeMemberArrayBoolean",
             "UniontypeMemberMap",
             "UniontypeMemberRegularStruct",
             "UniontypeMemberString",
             "UniontypeMemberTypedStruct"
           ] = possible_type_names
  end

  test "custom map type from union member is generated" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "PersonMapType") {
          name
          kind
          fields {
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

    assert data["__type"]["name"] == "PersonMapType"
    assert data["__type"]["kind"] == "OBJECT"

    field_names = Enum.map(data["__type"]["fields"], & &1["name"]) |> Enum.sort()
    assert ["age", "email", "name"] = field_names
  end

  test "custom map input type from union member is generated" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "PersonMapInputType") {
          name
          kind
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

    assert data["__type"]["name"] == "PersonMapInputType"
    assert data["__type"]["kind"] == "INPUT_OBJECT"

    field_names = Enum.map(data["__type"]["inputFields"], & &1["name"]) |> Enum.sort()
    assert ["age", "email", "name"] = field_names
  end

  test "union wrapper references custom type correctly" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "UniontypeMemberTypedStruct") {
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

    assert data["__type"]["name"] == "UniontypeMemberTypedStruct"
    assert data["__type"]["kind"] == "OBJECT"

    value_field = Enum.find(data["__type"]["fields"], &(&1["name"] == "value"))
    assert value_field["type"]["kind"] == "NON_NULL"
    assert value_field["type"]["ofType"]["name"] == "PersonType"
    assert value_field["type"]["ofType"]["kind"] == "OBJECT"

    {:ok, %{data: map_data}} =
      """
      query {
        __type(name: "UniontypeMemberMap") {
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

    assert map_data["__type"]["name"] == "UniontypeMemberMap"
    map_value_field = Enum.find(map_data["__type"]["fields"], &(&1["name"] == "value"))
    assert map_value_field["type"]["kind"] == "NON_NULL"
    assert map_value_field["type"]["ofType"]["name"] == "PersonMapType"
    assert map_value_field["type"]["ofType"]["kind"] == "OBJECT"

    {:ok, %{data: struct_data}} =
      """
      query {
        __type(name: "UniontypeMemberRegularStruct") {
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

    assert struct_data["__type"]["name"] == "UniontypeMemberRegularStruct"
    struct_value_field = Enum.find(struct_data["__type"]["fields"], &(&1["name"] == "value"))
    assert struct_value_field["type"]["kind"] == "NON_NULL"
    assert struct_value_field["type"]["ofType"]["name"] == "PersonRegularType"
    assert struct_value_field["type"]["ofType"]["kind"] == "OBJECT"
  end

  test "all custom types from union members are accessible via GraphQL introspection" do
    {:ok, %{data: map_data}} =
      """
      query {
        __type(name: "PersonMapType") {
          name
          kind
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert map_data["__type"]["name"] == "PersonMapType"
    assert map_data["__type"]["kind"] == "OBJECT"

    {:ok, %{data: typed_data}} =
      """
      query {
        __type(name: "PersonType") {
          name
          kind
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert typed_data["__type"]["name"] == "PersonType"
    assert typed_data["__type"]["kind"] == "OBJECT"

    {:ok, %{data: struct_data}} =
      """
      query {
        __type(name: "PersonRegularType") {
          name
          kind
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert struct_data["__type"]["name"] == "PersonRegularType"
    assert struct_data["__type"]["kind"] == "OBJECT"

    custom_input_types = [
      "PersonMapInputType",
      "PersonInputType",
      "PersonRegularInputType"
    ]

    Enum.each(custom_input_types, fn type_name ->
      {:ok, %{data: input_data}} =
        """
        query {
          __type(name: "#{type_name}") {
            name
            kind
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema)

      assert input_data["__type"]["name"] == type_name
      assert input_data["__type"]["kind"] == "INPUT_OBJECT"
    end)
  end
end
