defmodule AshGraphql.Test.RelayIds.ResourceWithNoPrimaryKeyGet do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :resource_with_no_primary_key_get

    queries do
      get :get_resource_by_name, :get_by_name
    end

    mutations do
      create :create_resource, :create
    end
  end

  actions do
    defaults([:create, :update, :destroy, :read])

    read(:get_by_name, get_by: :name)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false)
  end

  identities do
    identity(:name, [:name], pre_check_with: AshGraphql.Test.RelayIds.Api)
  end

  relationships do
    has_many(:posts, AshGraphql.Test.RelayIds.Post, destination_attribute: :author_id)
  end
end
