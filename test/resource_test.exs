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
end
