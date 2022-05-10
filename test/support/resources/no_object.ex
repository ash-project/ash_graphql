defmodule AshGraphql.Test.NoObject do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :no_object
    generate_object? false
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end
end
