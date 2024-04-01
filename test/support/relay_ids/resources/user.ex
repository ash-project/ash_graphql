defmodule AshGraphql.Test.RelayIds.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.RelayIds.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    queries do
      get :get_user, :read
    end

    mutations do
      create :create_user, :create
      update :assign_posts, :assign_posts, relay_id_translations: [input: [post_ids: :post]]
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :update, :destroy, :read])

    update :assign_posts do
      argument(:post_ids, {:array, :uuid})

      change(manage_relationship(:post_ids, :posts, value_is_key: :id, type: :append_and_remove))
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end

  relationships do
    has_many(:posts, AshGraphql.Test.RelayIds.Post,
      destination_attribute: :author_id,
      public?: true
    )
  end
end
