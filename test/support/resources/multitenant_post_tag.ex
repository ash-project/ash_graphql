defmodule AshGraphql.Test.MultitenantPostTag do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  relationships do
    belongs_to :post, AshGraphql.Test.Post do
      primary_key?(true)
      allow_nil?(false)
    end

    belongs_to :tag, AshGraphql.Test.MultitenantTag do
      primary_key?(true)
      allow_nil?(false)
    end
  end
end
