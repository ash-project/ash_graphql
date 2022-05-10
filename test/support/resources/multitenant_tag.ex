defmodule AshGraphql.Test.MultitenantTag do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:multitenant_tag)

    queries do
      get :get_multitenant_tag, :read
      list :get_multitenant_tags, :read
    end

    mutations do
      create :create_multitenant_tag, :create
      destroy :destroy_multitenant_tag, :destroy
    end
  end

  multitenancy do
    strategy(:context)
  end

  actions do
    create :create do
      primary?(true)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end

  identities do
    identity(:name, [:name])
  end

  relationships do
    many_to_many(:posts, AshGraphql.Test.Post,
      through: AshGraphql.Test.MultitenantPostTag,
      source_field_on_join_table: :tag_id,
      destination_field_on_join_table: :post_id
    )
  end
end
