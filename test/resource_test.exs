defmodule AshGraphql.ResourceTest do
  use ExUnit.Case

  test "object generated according to generate_object?" do
    assert %Absinthe.Type.Object{
             identifier: :user
           } = Absinthe.Schema.lookup_type(AshGraphql.Test.Schema, :user)

    assert nil == Absinthe.Schema.lookup_type(AshGraphql.Test.Schema, :no_object)
  end
end
