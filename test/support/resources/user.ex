defmodule AshGraphql.Test.User do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    queries do
      read_one :current_user, :current_user, allow_nil?: false
    end

    mutations do
      create :create_user, :create
      # update :update_user, :update
    end
  end

  actions do
    defaults([:create, :update, :destroy, :read])

    create(:create_policies)

    read :current_user do
      filter(id: actor(:id))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string)
  end

  calculations do
    calculate(:name_twice, :string, expr(name <> " " <> name))
  end

  policies do
    policy action_type(:create) do
      actor_attribute_equals(:name, "My Name")
    end

    policy action_type(:read) do
      authorize_if(always())
    end
  end
end
