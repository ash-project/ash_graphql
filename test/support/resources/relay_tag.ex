defmodule AshGraphql.Test.RelayTag do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:relay_tag)

    queries do
      get :get_relay_tag, :read
      list :get_relay_tags, :read_paginated, relay?: true
    end

    mutations do
      create :create_relay_tag, :create
      destroy :destroy_relay_tag, :destroy
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :update, :destroy, :read])

    read :read_paginated do
      pagination(required?: true, offset?: true, keyset?: true, countable: true)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
  end

  identities do
    identity(:name, [:name], pre_check_with: AshGraphql.Test.Domain)
  end

  relationships do
    many_to_many(:posts, AshGraphql.Test.Post,
      through: AshGraphql.Test.RelayPostTag,
      source_attribute_on_join_resource: :tag_id,
      destination_attribute_on_join_resource: :post_id
    )
  end
end
