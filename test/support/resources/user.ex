defmodule AshGraphql.Test.User do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    queries do
      read_one :current_user, :current_user, allow_nil?: false
    end
  end

  actions do
    read :current_user do
      filter(id: actor(:id))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end
end
