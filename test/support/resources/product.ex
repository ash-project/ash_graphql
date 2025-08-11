defmodule AshGraphql.Test.Product do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :product

    queries do
      get :get_product, :read
    end

    mutations do
      create :create_product, :create
      update :update_product, :update
      destroy :destroy_product, :destroy
    end

    subscriptions do
      pubsub AshGraphql.Test.PubSub

      subscribe(:product_events) do
        action_types([:create, :update, :destroy])
      end
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:organization_id)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :integer, public?: true)
    attribute(:name, :string, public?: true)
  end
end
