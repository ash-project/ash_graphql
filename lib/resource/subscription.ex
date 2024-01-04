defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :config,
    :resolve
  ]

  @subscription_schema [
    name: [
      type: :atom,
      doc: "The name to use for the subscription."
    ],
    config: [
      type:
        {:spark_function_behaviour, AshGraphql.Resource.Subscription.Config,
         {AshGraphql.Resource.Subscription.Config.Function, 2}},
      doc: """
      Function that creates the config for the subscription
      """
    ],
    resolve: [
      type:
        {:spark_function_behaviour, AshGraphql.Resource.Subscription.Resolve,
         {AshGraphql.Resource.Subscription.Resolve.Function, 3}},
      doc: """
      Function that creates the config for the subscription
      """,
      default: AshGraphql.Resource.Subscription.DefaultResolve
    ]
  ]

  def schema, do: @subscription_schema
end
