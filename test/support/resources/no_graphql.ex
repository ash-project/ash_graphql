defmodule AshGraphql.Test.NoGraphql do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.Post, allow_nil?: false)
  end
end
