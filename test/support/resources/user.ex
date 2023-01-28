defmodule AshGraphql.Test.User do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    queries do
      read_one(:current_user, :current_user)

      read_one :current_user_with_metadata, :current_user_with_metadata do
        type_name :user_with_bar
        metadata_names(foo: :bar)
      end
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

    read :current_user_with_metadata do
      metadata(:foo, :string)

      prepare(fn query, _ ->
        Ash.Query.after_action(query, fn _query, results ->
          {:ok,
           Enum.map(results, fn result ->
             Ash.Resource.put_metadata(result, :foo, "bar")
           end)}
        end)
      end)
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
