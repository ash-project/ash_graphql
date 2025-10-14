# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type :user

    nullable_fields([:secret])

    queries do
      read_one(:current_user, :current_user)

      read_one :current_user_with_metadata, :current_user_with_metadata do
        type_name :user_with_bar
        metadata_names(foo: :bar)
      end
    end

    mutations do
      create :create_user, :create

      update :authenticate_with_token, :authenticate_with_token do
        identity false
        read_action :get_by_token
      end

      destroy :delete_current_user, :destroy_current_user do
        identity false
      end
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

    update :authenticate_with_token do
      require_atomic?(false)
      metadata(:jwt, :string, allow_nil?: false)

      change(fn changeset, _struct ->
        changeset
        |> Ash.Changeset.after_action(fn changeset, customer ->
          {:ok, Ash.Resource.put_metadata(customer, :jwt, "dummy-jwt")}
        end)
      end)
    end

    read :get_by_token do
      get?(true)
      argument(:token, :string, allow_nil?: false)

      prepare(fn query, _ ->
        token = query.arguments.token

        case token do
          "valid-" <> _ ->
            # For testing, we'll allow this action to return whatever customer is found
            query

          _ ->
            Ash.Query.after_action(query, fn _query, _results ->
              error = %Ash.Error.Query.InvalidQuery{message: "test error"}
              {:error, error}
            end)
        end
      end)
    end

    destroy :destroy_current_user do
      filter(expr(id == ^actor(:id)))
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

    policy action_type(:destroy) do
      authorize_if(expr(id == ^actor(:id)))
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
