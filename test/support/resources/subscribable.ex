defmodule AshGraphql.Test.Subscribable do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :subscribable

    queries do
      get :get_subscribable, :read
    end

    mutations do
      create :create_subscribable, :create
      update :update_subscribable, :update
      destroy :destroy_subscribable, :destroy
    end

    subscriptions do
      pubsub(AshGraphql.Test.PubSub)

      subscribe(:subscribable_events) do
        actions([:create, :update, :destroy])
      end
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string, public?: true)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end
end
