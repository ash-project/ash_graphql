defmodule AshGraphql.Test.TextMessage do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  ets do
    table(:message)
  end

  resource do
    base_filter(type: :text)
  end

  graphql do
    type(:text_message)
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary?(true)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string)

    attribute(:type, :atom, default: :text, constraints: [one_of: [:text, :image]])
  end

  relationships do
    belongs_to(:channel, AshGraphql.Test.Channel)
  end
end
