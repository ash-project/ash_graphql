defmodule AshGraphql.EnumTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "enum without value descriptions returns a nil description" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "StatusEnum") {
          enumValues {
            name
            description
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert %{"name" => "CLOSED", "description" => nil} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "CLOSED" end)

    assert %{"name" => "OPEN", "description" => nil} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "OPEN" end)
  end

  test "Ash.Type.Enum value descriptions are used as description source" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "EnumWithAshDescription") {
          enumValues {
            name
            description
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert %{"name" => "FIZZ", "description" => "A fizz"} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "FIZZ" end)

    assert %{"name" => "BUZZ", "description" => "A buzz"} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "BUZZ" end)
  end

  test "graphql_describe_enum_value/1 overrides Ash.Type.Enum descriptions" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "EnumWithAshGraphqlDescription") {
          enumValues {
            name
            description
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    assert %{"name" => "FOO", "description" => "A foo"} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "FOO" end)

    assert %{"name" => "BAR", "description" => "A bar"} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "BAR" end)

    assert %{"name" => "NO_DESCRIPTION", "description" => nil} =
             data["__type"]["enumValues"]
             |> Enum.find(fn value -> value["name"] == "NO_DESCRIPTION" end)
  end
end
