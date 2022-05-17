defmodule AshGraphql.Test.DoubleRelRecursive do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  alias AshGraphql.Test.DoubleRelEmbed
  alias AshGraphql.Test.DoubleRelRecursive
  alias AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed
  alias AshGraphql.Test.DoubleRelType

  attributes do
    uuid_primary_key(:id)
    attribute(:type, DoubleRelType, allow_nil?: true)
    attribute(:this, :string, allow_nil?: true)
    attribute(:or_that, DoubleRelEmbed, allow_nil?: true)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  graphql do
    type :double_rel_recursive
  end

  relationships do
    belongs_to :double_rel, DoubleRelToRecursiveParentOfEmbed do
      source_field(:double_rel_id)
      required?(true)
    end

    belongs_to :myself, DoubleRelRecursive do
      source_field(:recursive_id)
      required?(false)
      private?(true)
    end

    has_many :first_rel, DoubleRelRecursive do
      destination_field(:recursive_id)
      filter(expr(type == :first))
    end

    has_many :second_rel, DoubleRelRecursive do
      destination_field(:recursive_id)
      filter(expr(type == :second))
    end
  end
end
