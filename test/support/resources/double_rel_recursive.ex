defmodule AshGraphql.Test.DoubleRelRecursive do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  alias AshGraphql.Test.DoubleRelEmbed
  alias AshGraphql.Test.DoubleRelRecursive
  alias AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed
  alias AshGraphql.Test.DoubleRelType

  attributes do
    uuid_primary_key(:id)
    attribute(:type, DoubleRelType, allow_nil?: true, public?: true)
    attribute(:this, :string, allow_nil?: true, public?: true)
    attribute(:or_that, DoubleRelEmbed, allow_nil?: true, public?: true)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  graphql do
    type :double_rel_recursive
  end

  relationships do
    belongs_to :double_rel, DoubleRelToRecursiveParentOfEmbed do
      public?(true)
      source_attribute(:double_rel_id)
      allow_nil?(false)
    end

    belongs_to :myself, DoubleRelRecursive do
      source_attribute(:recursive_id)
      allow_nil?(false)
      public?(true)
    end

    has_many :first_rel, DoubleRelRecursive do
      public?(true)
      destination_attribute(:recursive_id)
      filter(expr(type == :first))
    end

    has_many :second_rel, DoubleRelRecursive do
      public?(true)
      destination_attribute(:recursive_id)
      filter(expr(type == :second))
    end
  end
end
