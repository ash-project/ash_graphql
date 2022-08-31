defmodule AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  alias AshGraphql.Test.DoubleRelRecursive

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
