# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Message do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table(:message)
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

    attribute(:text, :string, public?: true)

    attribute(:type, :atom, default: :text, constraints: [one_of: [:text, :image]], public?: true)
  end

  relationships do
    belongs_to(:channel, AshGraphql.Test.Channel, public?: true)

    has_many(:message_users, AshGraphql.Test.MessageViewableUser,
      destination_attribute: :message_id
    )
  end
end
