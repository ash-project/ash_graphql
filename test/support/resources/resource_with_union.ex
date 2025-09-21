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

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:resource_with_union)

    queries do
    end

    mutations do
      action(:action_with_union_arg, :action_with_union_arg)
    end
  end

  actions do
    default_accept(:*)

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
