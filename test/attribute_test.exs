defmodule AshGraphql.AttributeTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Api)

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

  @tag :wip
  test "map attribute with field constraints uses objects for inputs" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "MapTypes") {
          fields {
            name
            description
            args {
              name
              description
            }
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
      |> IO.inspect()
  end
end
