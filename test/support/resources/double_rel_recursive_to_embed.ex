defmodule AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  alias AshGraphql.Test.DoubleRelRecursive

  actions do
    default_accept(:*)
    defaults([:read, :create, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:dummy, :string, default: "Dummy")
  end

  graphql do
    type :double_rel
  end

  relationships do
    has_many :all, DoubleRelRecursive do
      destination_attribute(:double_rel_id)
    end
  end
end
