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
    read_action: [
      type: :atom,
      doc: "The read action to use for reading data"
    ]
  ]

  def schema, do: @subscription_schema
end
