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
    refute input_fields |> Enum.find(fn field -> field["name"] == "popularity" end)
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
