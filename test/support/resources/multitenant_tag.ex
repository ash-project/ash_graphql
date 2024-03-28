defmodule AshGraphql.Test.MultitenantTag do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
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
    default_accept(:*)
    defaults([:read, :update, :destroy])

    create :create do
      primary?(true)
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
      through: AshGraphql.Test.MultitenantPostTag,
      source_attribute_on_join_resource: :tag_id,
      destination_attribute_on_join_resource: :post_id,
      public?: true
    )
  end
end
