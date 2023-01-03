defmodule AshGraphql.AttributeTest do
  use ExUnit.Case, async: false

  setup do
    Application.delete_env(:ash_graphql, AshGraphql.Test.Api)

    on_exit(fn ->
      try do
        AshGraphql.TestHelpers.stop_ets()
      rescue
        _ ->
          :ok
      end
    end)
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
end
