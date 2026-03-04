# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.TagWithIlike do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: AshGraphql.Test.DataLayer.EtsWithFunctions,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:tag_with_ilike)

    filterable_fields [:name, label: [:eq, :ilike]]

    queries do
      list :get_tags_with_ilike, :read
    end
  end

  actions do
    default_accept(:*)
    defaults([:read, :create])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
    attribute(:label, AshGraphql.Types.StringNewType, public?: true)
  end
end
