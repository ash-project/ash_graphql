defmodule AshGraphql.Test.PostTag do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:create, :update, :destroy, :read])
  end

  relationships do
    belongs_to :post, AshGraphql.Test.Post do
      primary_key?(true)
      allow_nil?(false)
    end

    belongs_to :tag, AshGraphql.Test.Tag do
      primary_key?(true)
      allow_nil?(false)
    end
  end
end
