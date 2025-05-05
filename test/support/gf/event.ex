defmodule GF.Event do
  @moduledoc """
  Event Ash resource.
  """

  use Ash.Resource,
    domain: GF.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  alias GF.Attendee

  attributes do
    uuid_primary_key(:id)

    attribute(:description, :string, public?: true)
    attribute(:group_id, :uuid, public?: false)

    attribute(:start_at, :utc_datetime, public?: true)
    attribute(:title, :string, public?: true)

    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  relationships do
    has_many(:attendees, Attendee, public?: true)
  end

  graphql do
    type :gf_event

    queries do
      get :get_event, :read
    end
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: :id, not_found_error?: false)
    define(:create, action: :create)
  end
end
