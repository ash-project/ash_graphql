defmodule AshGraphql.Test.Subscribable do
  @moduledoc false
  alias AshGraphql.Test.PubSub

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  resource do
    simple_notifiers([AshGraphql.Resource.Notifier])
  end

  graphql do
    type :subscribable

    queries do
      get :get_subscribable, :read
    end

    mutations do
      create :create_subscribable, :create
    end
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
