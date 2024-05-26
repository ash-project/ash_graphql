defmodule AshGraphql.Test.Award do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:award)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
  end

  relationships do
    belongs_to(:movie, AshGraphql.Test.Movie, public?: true)
  end
end
