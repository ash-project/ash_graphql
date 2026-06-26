# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.EmptyInputEmbed do
  @moduledoc false

  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :empty_input_embed
  end

  actions do
    create :create do
      primary?(true)
      accept([])
    end

    update :update do
      primary?(true)
      accept([])
    end
  end

  attributes do
    attribute :type, :atom do
      public?(true)
      writable?(false)
      constraints(one_of: [:empty_input_embed])
    end
  end
end

defmodule AshGraphql.Test.ResourceWithEmptyInputEmbed do
  @moduledoc false

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :resource_with_empty_input_embed
  end

  actions do
    default_accept(:*)
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :empty_value, AshGraphql.Test.EmptyInputEmbed do
      public?(true)
    end
  end
end
