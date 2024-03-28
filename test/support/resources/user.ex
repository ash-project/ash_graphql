defmodule AshGraphql.Test.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
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
    default_accept(:*)

    defaults([:create, :update, :destroy, :read])

    create(:create_policies)

    read :current_user do
      filter(expr(id == ^actor(:id)))
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

    attribute(:name, :string, public?: true)

    attribute(:secret, :string) do
      public?(true)
      allow_nil? false
      default("super secret")
    end
  end

  relationships do
    has_many(:posts, AshGraphql.Test.Post, destination_attribute: :author_id, public?: true)
  end

  calculations do
    calculate(:name_twice, :string, expr(name <> " " <> name), public?: true)
  end

  policies do
    policy action_type(:create) do
      authorize_if(changing_attributes(name: [to: "My Name"]))
    end

    policy action_type(:read) do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :secret do
      forbid_if(always())
    end

    field_policy :* do
      authorize_if(always())
    end
  end
end
