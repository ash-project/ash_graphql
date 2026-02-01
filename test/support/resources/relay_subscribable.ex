# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelaySubscribable do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.RelayDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :relay_subscribable

    mutations do
      update :update_relay_subscribable, :update
      destroy :destroy_subscribable_relay, :destroy
    end

    subscriptions do
      pubsub AshGraphql.Test.PubSub

      subscribe(:subscribable_events_relay) do
        action_types([:create, :update, :destroy])
      end

      subscribe(:subscribable_deleted_relay) do
        action_types(:destroy)
      end

      subscribe(:subscribable_events_relay_with_arguments) do
        read_action(:read_with_arg)
        actions([:create])
      end

      subscribe(:subscribable_events_relay_with_id_filter) do
        read_action(:read_with_id_arg)
        action_types([:create, :update, :destroy])
        relay_id_translations(subscribable_id: :relay_subscribable)
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

    policy action([:open_read, :read_with_arg, :read_with_id_arg]) do
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

    read :read_with_id_arg do
      argument(:subscribable_id, :uuid) do
        allow_nil? false
      end

      filter(expr(id == ^arg(:subscribable_id)))
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
