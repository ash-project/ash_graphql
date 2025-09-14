defmodule AshGraphql.UnionTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "typed_struct as union member" do
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

    assert [
             %{"name" => "UniontypeMemberArrayBoolean"},
             %{"name" => "UniontypeMemberString"},
             %{"name" => "UniontypeMemberTypedStruct"}
           ] =
             data["__type"]["possibleTypes"]
  end
end
