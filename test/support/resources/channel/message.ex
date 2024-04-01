defmodule AshGraphql.Test.Message do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  # extensions: [AshGraphql.Resource]

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
  end

  # graphql do
  #   type :message
  # end
end
