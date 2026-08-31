# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.Payment do
  @moduledoc """
  Exposes a card number as a non-expression calculation, and filters it through
  a private blind index attribute using a `filter_handlers` handler.
  """

  use Ash.Resource,
    domain: AshGraphql.Test.RelayIds.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :payment

    filter_handlers card_number: [
                      type: :string,
                      handler:
                        {AshGraphql.Test.RelayIds.BlindIndex, :filter, [:card_number_hash]},
                      description: "Filter by card number using its blind index"
                    ]

    queries do
      list :list_payments, :read
    end
  end

  actions do
    default_accept(:*)
    defaults([:read])

    create :create do
      primary?(true)

      argument(:card_number, :string, allow_nil?: false)

      change(fn changeset, _ ->
        card_number = Ash.Changeset.get_argument(changeset, :card_number)

        changeset
        |> Ash.Changeset.force_change_attribute(:stored_card_number, card_number)
        |> Ash.Changeset.force_change_attribute(
          :card_number_hash,
          AshGraphql.Test.RelayIds.BlindIndex.hash(card_number)
        )
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:description, :string, public?: true)
    attribute(:stored_card_number, :string, public?: false)
    attribute(:card_number_hash, :string, public?: false)
  end

  calculations do
    calculate(:card_number, :string, AshGraphql.Test.RelayIds.BlindIndex) do
      public?(true)
    end
  end
end
