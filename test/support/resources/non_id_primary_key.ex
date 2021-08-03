defmodule AshGraphql.Test.NonIdPrimaryKey do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :non_id_primary_key

    queries do
      get :get_non_id_primary_key, :read
    end
  end

  attributes do
    uuid_primary_key(:other)
  end
end
