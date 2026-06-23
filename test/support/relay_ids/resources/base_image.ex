# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.BaseImage do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.RelayIds.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :base_image

    filter_handlers id: [
                      type: :id,
                      handler: {AshGraphql.Graphql.FilterHandlers, :relay_id, [:base_image]},
                      description: "Filter by Relay global ID"
                    ]

    queries do
      get :get_base_image, :read
      list :list_base_images, :read
      read_one :read_one_base_image, :read
    end

    mutations do
      create :create_base_image, :create
      update :update_base_image, :update
    end

    subscriptions do
      pubsub AshGraphql.Test.PubSub

      subscribe :base_image_events do
        action_types([:create, :update])
      end
    end
  end

  actions do
    default_accept(:*)
    defaults([:read, :update])

    create :create do
      primary?(true)

      change(fn changeset, _ ->
        if Ash.Changeset.get_attribute(changeset, :id) do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            :id,
            System.unique_integer([:positive, :monotonic])
          )
        end
      end)
    end
  end

  attributes do
    integer_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end
