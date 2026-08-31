# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.Customer do
  @moduledoc """
  Exposes a card number as an aggregate that must not be filtered directly, and
  filters it through a private blind index aggregate using a `filter_handlers`
  handler.
  """

  use Ash.Resource,
    domain: AshGraphql.Test.RelayIds.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :customer

    filter_handlers card_number: [
                      type: :string,
                      handler:
                        {AshGraphql.Test.RelayIds.BlindIndex, :filter, [:card_number_hash]},
                      description: "Filter by card number using its blind index"
                    ]

    queries do
      list :list_customers, :read
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end

  relationships do
    has_many(:payments, AshGraphql.Test.RelayIds.Payment, public?: true)
  end

  aggregates do
    first :card_number, :payments, :stored_card_number do
      public?(true)
      filterable?(false)
    end

    first(:card_number_hash, :payments, :card_number_hash)
  end
end
