defmodule AshGraphql.Resource.Subscription do
  @moduledoc "Represents a configured query on a resource"
  defstruct [
    :name,
    # :arg = filter,
    :config,
    :read_action
    # :topic, fn _, _ -> {:ok, topic} | :error,
    # :trigger fn notification -> {:ok, topics}
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
      """
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
