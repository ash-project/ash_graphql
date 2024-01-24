defmodule AshGraphql.Test.RelayIds.User do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    queries do
      get :get_user, :read
    end

    mutations do
      create :create_user, :create
    end
  end

  actions do
    defaults([:create, :update, :destroy, :read])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  relationships do
    has_many(:posts, AshGraphql.Test.RelayIds.Post, destination_attribute: :author_id)
  end
end
