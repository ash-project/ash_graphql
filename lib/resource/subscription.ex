defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :resource,
    :actions,
    :action_types,
    :read_action,
    :actor,
    :hide_input
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
      doc: "A list of inputs to hide from the mutation.",
      default: []
    ]
  ]

  def schema, do: @subscription_schema
end
