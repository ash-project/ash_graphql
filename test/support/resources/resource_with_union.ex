# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResourceWithUnion do
  @moduledoc false

  alias AshGraphql.Test.PersonMap
  alias AshGraphql.Test.PersonRegularStruct
  alias AshGraphql.Test.PersonTypedStructData

  defmodule Union do
    @moduledoc false

    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          member_array_boolean: [
            type: {:array, :boolean},
            tag: :type,
            tag_value: "member_array_boolean"
          ],
          member_string: [
            type: :string,
            tag: :type,
            tag_value: "member_string"
          ],
          member_map: [
            type: PersonMap,
            tag: :type,
            tag_value: "member_map"
          ],
          member_typed_struct: [
            type: PersonTypedStructData,
            tag: :type,
            tag_value: "member_typed_struct"
          ],
          member_regular_struct: [
            type: PersonRegularStruct,
            tag: :type,
            tag_value: "member_regular_struct"
          ]
        ]
      ]

    use AshGraphql.Type

    @impl true
    def graphql_type(_), do: :uniontype

    @impl true
    def graphql_input_type(_), do: :uniontype_input
  end

  defmodule GenericActionUnion do
    @moduledoc false

    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          string_result: [
            type: :string,
            tag: :type,
            tag_value: "string_result"
          ],
          integer_result: [
            type: :integer,
            tag: :type,
            tag_value: "integer_result"
          ]
        ]
      ]

    def graphql_type(_), do: :generic_action_union
    def graphql_input_type(_), do: :generic_action_union_input
  end

  defmodule GenericActionUnnestedUnion do
    @moduledoc false

    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          foo: [
            type: Foo,
            tag: :type,
            tag_value: :foo
          ],
          typed_struct: [
            type: AshGraphql.Test.PersonTypedStructData
          ]
        ]
      ]

    use AshGraphql.Type

    @impl true
    def graphql_type(_), do: :generic_action_unnested_union

    @impl true
    def graphql_unnested_unions(_), do: [:foo, :typed_struct]
  end

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:resource_with_union)

    queries do
      action(:search_unions, :search_unions)
      action(:unnested_union, :unnested_union)
      action(:unnested_unions, :unnested_unions)
    end

    mutations do
      action(:action_with_union_arg, :action_with_union_arg)
    end
  end

  actions do
    default_accept(:*)

    action :search_unions, {:array, GenericActionUnion} do
      run(fn _input, _ctx ->
        {:ok, []}
      end)
    end

    action :unnested_union, GenericActionUnnestedUnion do
      run(fn _input, _ctx ->
        {:ok,
         %Ash.Union{
           type: :typed_struct,
           value: %PersonTypedStructData{name: "Alice"}
         }}
      end)
    end

    action :unnested_unions, {:array, GenericActionUnnestedUnion} do
      run(fn _input, _ctx ->
        {:ok,
         [
           %Ash.Union{type: :foo, value: %Foo{type: :foo, foo: "foo"}},
           %Ash.Union{
             type: :typed_struct,
             value: %PersonTypedStructData{name: "Alice"}
           }
         ]}
      end)
    end

    action :action_with_union_arg, :boolean do
      argument(:union_arg, Union, allow_nil?: false)

      run(fn _inputs, _ctx ->
        {:ok, true}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end
end
