# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :resource,
    :actions,
    :action_types,
    :read_action,
    :actor,
    :hide_inputs,
    :relay_id_translations,
    :meta,
    :__spark_metadata__
  ]

  @subscription_schema [
    name: [
      type: :atom,
      doc: "The name to use for the subscription."
    ],
    actor: [
      type:
        {:spark_function_behaviour, AshGraphql.Subscription.Actor,
         {AshGraphql.Subscription.ActorFunction, 1}},
      doc: "The actor to use for authorization."
    ],
    actions: [
      type: {:or, [{:list, :atom}, :atom]},
      doc: "The create/update/destroy actions the subsciption should listen to."
    ],
    action_types: [
      type: {:or, [{:list, :atom}, :atom]},
      doc: "The type of actions the subsciption should listen to."
    ],
    read_action: [
      type: :atom,
      doc: "The read action to use for reading data"
    ],
    hide_inputs: [
      type: {:list, :atom},
      doc:
        "A list of inputs to hide from the subscription, usable if the read action has arguments.",
      default: []
    ],
    relay_id_translations: [
      type: :keyword_list,
      doc: """
      A keyword list indicating arguments or attributes that have to be translated from global Relay IDs to internal IDs. See the [Relay guide](/documentation/topics/relay.md#translating-relay-global-ids-passed-as-arguments) for more.
      """,
      default: []
    ],
    meta: [
      type: :keyword_list,
      doc: "A keyword list of metadata to include in the subscription."
    ]
  ]

  def schema, do: @subscription_schema
end
