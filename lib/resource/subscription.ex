defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :actions,
    :read_action,
    :actor
  ]

  @subscription_schema [
    name: [
      type: :atom,
      doc: "The name to use for the subscription."
    ],
    actor: [
      type:
        {:spark_function_behaviour, AshGraphql.Resource.Subscription.Actor,
         {AshGraphql.Resource.Subscription.Actor, 1}},
      doc: "The actor to use for authorization."
    ],
    actions: [
      type: {:or, [{:list, :atom}, :atom]},
      doc: "The create/update/destroy actions the subsciption should listen to. Defaults to all."
    ],
    read_action: [
      type: :atom,
      doc: "The read action to use for reading data"
    ]
  ]

  def schema, do: @subscription_schema
end
