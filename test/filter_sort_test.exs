# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.FilterSortTest do
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

  test "filterable_fields option is applied" do
    resp =
      """
      query {
        __type(name: "TagFilterInput") {
          name
          kind
          inputFields {
            name
          }
        }
      }

      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, %{data: %{"__type" => %{"inputFields" => input_fields}}}} = resp

    assert input_fields |> Enum.find(fn field -> field["name"] == "name" end)
    assert input_fields |> Enum.find(fn field -> field["name"] == "popularity" end)
    refute input_fields |> Enum.find(fn field -> field["name"] == "id" end)
  end

  test "filterable_fields per-field operator restriction is applied" do
    resp =
      """
      query {
        __type(name: "TagFilterPopularity") {
          inputFields {
            name
          }
        }
      }

      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, %{data: %{"__type" => %{"inputFields" => input_fields}}}} = resp

    field_names = Enum.map(input_fields, & &1["name"])
    assert "eq" in field_names
    assert "in" in field_names
    refute "lessThan" in field_names
    refute "greaterThan" in field_names
    refute "lessThanOrEqual" in field_names
    refute "greaterThanOrEqual" in field_names
  end

  test "filterable_fields bare atom allows all operators" do
    resp =
      """
      query {
        __type(name: "TagFilterName") {
          inputFields {
            name
          }
        }
      }

      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, %{data: %{"__type" => %{"inputFields" => input_fields}}}} = resp

    field_names = Enum.map(input_fields, & &1["name"])
    assert "eq" in field_names
    assert "lessThan" in field_names
    assert "greaterThan" in field_names
  end

  test "sortable_fields option is applied" do
    resp =
      """
      query {
        __type(name: "TagSortField") {
          name
          kind
          enumValues {
            name
          }
        }
      }

      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert {:ok, %{data: %{"__type" => %{"enumValues" => sort_fields}}}} = resp

    assert sort_fields |> Enum.find(fn field -> field["name"] == "POPULARITY" end)
    refute sort_fields |> Enum.find(fn field -> field["name"] == "NAME" end)
  end
end
