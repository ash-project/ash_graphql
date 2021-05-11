defmodule AshGraphql.Test.Tag do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:tag)

    queries do
      get :get_tag, :read
      list :get_tags, :read
      # list :paginated_tags, :paginated
    end

    mutations do
      create :create_tag, :create
      destroy :destroy_tag, :destroy
    end
  end

  actions do
    create :create do
      primary?(true)
    end

    # read :paginated do
    #   pagination(required?: true, offset?: true, countable: true)
    # end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end

  identities do
    identity :name, [:name]
  end

  relationships do
    many_to_many(:posts, AshGraphql.Test.Post, through: AshGraphql.Test.PostTag, source_field_on_join_table: :tag_id, destination_field_on_join_table: :post_id)
  end
end
