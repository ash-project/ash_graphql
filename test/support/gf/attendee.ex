# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.Attendee do
  @moduledoc """
  An attendee record for ane event.
  """

  use Ash.Resource,
    domain: GF.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource],
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query
  require Ash.Sort

  alias GF.Member

  actions do
    default_accept(:*)
    defaults([:create, :update, :read, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:event_id, :uuid, public?: true)
    attribute(:member_id, :uuid, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:member, Member, public?: true)
  end

  policies do
    policy action(:read) do
      authorize_if(actor_present())
    end
  end

  graphql do
    type :gf_attendee
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: :id, not_found_error?: false)
    define(:create, action: :create)
    define(:update, action: :update)
  end
end
