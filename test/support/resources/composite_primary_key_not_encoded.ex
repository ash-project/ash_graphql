defmodule AshGraphql.Test.CompositePrimaryKeyNotEncoded do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :composite_primary_key_not_encoded
    encode_primary_key? false

    queries do
      get :get_composite_primary_key_not_encoded, :read
    end
  end

  actions do
    defaults([:create, :update, :destroy, :read])
  end

  attributes do
    uuid_primary_key(:first)
    uuid_primary_key(:second)
  end
end
