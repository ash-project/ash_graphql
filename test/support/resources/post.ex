defmodule AshGraphql.Test.Post do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :post

    queries do
      get :get_post, :read
    end

    mutations do
      create :create_post, :create_confirm
    end
  end

  actions do
    create :create do
      primary?(true)
    end

    create :create_confirm do
      argument(:confirmation, :string)
      change(confirm(:text, :confirmation))
    end

    read(:read)
    update(:update)
    destroy(:destroy)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string)
  end
end
