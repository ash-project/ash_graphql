defmodule AshGraphql.Subscription do
  @moduledoc """
  Helpers for working with absinthe subscriptions
  """

  import AshGraphql.ContextHelpers

  @doc """
  Produce a query that will load the correct data for a subscription.
  """
  def query_for_subscription(query, %{arguments: args, context: context} = resolution) do
    query
    |> Ash.Query.set_tenant(Map.get(context, :tenant))
    |> Ash.Query.set_context(get_context(context))
    |> AshGraphql.Graphql.Resolver.set_query_arguments(query.action, args)
    |> AshGraphql.Graphql.Resolver.select_fields(query.resource, resolution)
  end
end
