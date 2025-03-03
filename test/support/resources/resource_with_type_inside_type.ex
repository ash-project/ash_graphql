defmodule AshGraphql.Test.ResourceWithTypeInsideType do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:resource_with_type_inside)

    queries do
    end

    mutations do
      action :create_type_inside_type, :custom_action
    end
  end

  actions do
    default_accept(:*)

    action :custom_action, :boolean do
      argument(:type_with_type, AshGraphql.Test.TypeWithTypeInside, allow_nil?: false)

      run(fn _inputs, _ctx ->
        {:ok, true}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:foo, :string, public?: true)
  end
end
