# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Subscribable do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :subscribable

    queries do
      get :get_subscribable, :read
    end

    mutations do
      create :create_subscribable, :create do
        meta meta_string: "bar", meta_integer: 1
      end

      update :update_subscribable, :update
      destroy :destroy_subscribable, :destroy
    end

    subscriptions do
      pubsub AshGraphql.Test.PubSub

      subscribe(:subscribable_events) do
        action_types([:create, :update, :destroy])
      end

      subscribe(:deduped_subscribable_events) do
        actions([:create, :update, :destroy])
        read_action(:open_read)

        actor(fn _ ->
          %{id: -1, role: :deduped_actor}
        end)
      end

      subscribe(:subscribable_events_with_arguments) do
        read_action(:read_with_arg)
        actions([:create])
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action(:read) do
      authorize_if(expr(actor_id == ^actor(:id)))
    end

    policy action([:open_read, :read_with_arg]) do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :hidden_field do
      authorize_if(actor_attribute_equals(:role, :admin))
    end

    field_policy :* do
      authorize_if(always())
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])

    read(:open_read)

    read :read_with_arg do
      argument(:topic, :string) do
        allow_nil? false
      end

      filter(expr(topic == ^arg(:topic)))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:hidden_field, :string) do
      public?(true)
      default("hidden")
      allow_nil?(false)
    end

    attribute(:text, :string, public?: true)
    attribute(:topic, :string, public?: true)
    attribute(:actor_id, :integer, public?: true)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end
end
