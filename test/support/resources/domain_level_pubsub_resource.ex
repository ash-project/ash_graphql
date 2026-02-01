# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.DomainLevelPubsubResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :domain_level_pubsub_resource

    queries do
      get :get_domain_level_pubsub_resource, :read
    end

    mutations do
      create :create_domain_level_pubsub_resource, :create
      update :update_domain_level_pubsub_resource, :update
      destroy :destroy_domain_level_pubsub_resource, :destroy
    end

    subscriptions do
      # No pubsub specified here - should inherit from domain
      subscribe(:domain_level_pubsub_events) do
        action_types([:create, :update, :destroy])
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
  end

  field_policies do
    field_policy :* do
      authorize_if(always())
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string, public?: true)
    attribute(:actor_id, :integer, public?: true)
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end
end
