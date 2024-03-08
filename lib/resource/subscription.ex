defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    :config,
    :read_action
  ]

  @subscription_schema [
    name: [
      type: :atom,
      doc: "The name to use for the subscription."
    ],
    config: [
      type: {:mfa_or_fun, 2},
      doc: """
      Function that creates the config for the subscription
      """,
      default: AshGraphql.Resource.Subscription.DefaultConfig
    ],
    resolve: [
      type: {:mfa_or_fun, 3},
      doc: """
      Function that creates the config for the subscription
      """,
      default: AshGraphql.Resource.Subscription.DefaultResolve
    ]
  ]

  def schema, do: @subscription_schema
end
