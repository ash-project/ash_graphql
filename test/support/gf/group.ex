# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.Group do
  @moduledoc "An Ash-managed GroupFlow Group (customer)"

  use Ash.Resource,
    domain: GF.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  @type t :: %__MODULE__{}

  # Attributes are the simple pieces of data that exist on your resource
  attributes do
    uuid_primary_key(:id)

    attribute(:abbreviation, :string, public?: true)
    attribute(:name, :string, public?: true)

    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end

  actions do
    default_accept(:*)
    # Add a set of simple actions. You'll customize these later.
    defaults([:create, :read, :update, :destroy])
  end

  graphql do
    type :group2
  end

  code_interface do
    define(:create, action: :create)
  end
end
