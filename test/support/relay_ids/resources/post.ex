defmodule AshGraphql.Test.RelayIds.Post do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :post

    queries do
      get :get_post, :read
      list :post_library, :read
    end

    mutations do
      create :simple_create_post, :create, relay_id_translations: [input: [author_id: :user]]
      update :update_post, :update
      update :assign_author, :assign_author, relay_id_translations: [input: [author_id: :user]]
      destroy :delete_post, :destroy
    end
  end

  actions do
    defaults([:update, :read, :destroy])

    create :create do
      primary?(true)
      argument(:author_id, :uuid)

      change(set_attribute(:author_id, arg(:author_id)))
    end

    update :assign_author do
      argument(:author_id, :uuid)

      change(set_attribute(:author_id, arg(:author_id)))
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string)
  end

  relationships do
    belongs_to(:author, AshGraphql.Test.RelayIds.User) do
      attribute_writable?(true)
    end
  end
end
