# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Tag do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:tag)

    filterable_fields [:name]
    sortable_fields [:popularity]

    queries do
      get :get_tag, :read
      list :get_tags, :read
    end

    mutations do
      create :create_tag, :create
      destroy :destroy_tag, :destroy
    end
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
    attribute(:popularity, :integer, public?: true)
  end

  identities do
    identity(:name, [:name], pre_check_with: AshGraphql.Test.Domain)
  end

  relationships do
    many_to_many(:posts, AshGraphql.Test.Post,
      through: AshGraphql.Test.PostTag,
      source_attribute_on_join_resource: :tag_id,
      destination_attribute_on_join_resource: :post_id
    )
  end
end
