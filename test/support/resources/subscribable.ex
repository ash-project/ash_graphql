defmodule AshGraphql.Test.Subscribable do
  @moduledoc false
  alias AshGraphql.Test.PubSub

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :subscribable

    queries do
      get :get_subscribable, :read
    end

    mutations do
      create :create_subscribable, :create
    end
  end

  pub_sub do
    module(PubSub)
    prefix("subscribable")
    broadcast_type(:notification)

    publish_all(:create, "created")
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end
end
