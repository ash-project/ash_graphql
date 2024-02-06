defmodule AshGraphql.Test.Subscribable do
  @moduledoc false
  use Ash.Resource,
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
    end

    subscriptions do
      subscribe(:subscribable_created, fn _, _ ->
        IO.inspect("bucket_created")
        {:ok, topic: "*"}
      end)
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
