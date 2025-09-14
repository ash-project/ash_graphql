defmodule AshGraphql.Test.ResourceWithUnion do
  @moduledoc false

  defmodule TypedStruct do
    use Ash.TypedStruct

    typed_struct do
      field(:foo, :string, allow_nil?: false)
    end

    use AshGraphql.Type

    @impl true
    def graphql_type(_), do: :typedtype

    @impl true
    def graphql_input_type(_), do: :typedtype_input
  end

  defmodule Union do
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
          member_typed_struct: [
            type: TypedStruct,
            tag: :type,
            tag_value: "member_typed_struct"
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
