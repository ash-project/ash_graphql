# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.NestedStructEnumTest do
  use ExUnit.Case, async: true

  defmodule EnumViaCalc do
    @moduledoc false
    use Ash.Type.Enum, values: [:low, :high]
    def graphql_type(_), do: :nested_struct_enum_via_calc
  end

  defmodule StructViaCalc do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field(:field, EnumViaCalc)
    end

    def graphql_type(_), do: :nested_struct_via_calc
  end

  defmodule EnumViaAttribute do
    @moduledoc false
    use Ash.Type.Enum, values: [:low, :high]
    def graphql_type(_), do: :nested_struct_enum_via_attribute
  end

  defmodule StructViaAttribute do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field(:field, EnumViaAttribute)
    end

    def graphql_type(_), do: :nested_struct_via_attribute
  end

  defmodule Thing do
    @moduledoc false
    use Ash.Resource,
      domain: AshGraphql.NestedStructEnumTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    attributes do
      uuid_primary_key(:id)

      attribute :struct_via_attribute, AshGraphql.NestedStructEnumTest.StructViaAttribute do
        public?(true)
      end
    end

    actions do
      defaults([:read])
    end

    calculations do
      calculate :struct_via_calc, AshGraphql.NestedStructEnumTest.StructViaCalc, expr(nil) do
        public?(true)
      end
    end

    graphql do
      type :nested_struct_enum_thing

      queries do
        list :things, :read
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, otp_app: :ash_graphql, extensions: [AshGraphql.Domain]

    resources do
      resource(AshGraphql.NestedStructEnumTest.Thing)
    end
  end

  defmodule Schema do
    @moduledoc false
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.NestedStructEnumTest.Domain]

    query do
    end
  end

  test "an enum nested in a struct reached only via a calculation is registered" do
    assert %Absinthe.Type.Enum{} =
             Absinthe.Schema.lookup_type(Schema, :nested_struct_enum_via_calc)

    assert Absinthe.Schema.to_sdl(Schema) =~ "field: NestedStructEnumViaCalc"
  end

  test "an enum nested in a struct reached only via an attribute is registered" do
    assert %Absinthe.Type.Enum{} =
             Absinthe.Schema.lookup_type(Schema, :nested_struct_enum_via_attribute)

    assert Absinthe.Schema.to_sdl(Schema) =~ "field: NestedStructEnumViaAttribute"
  end
end
