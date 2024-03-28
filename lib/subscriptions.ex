defmodule AshGraphql.Subscription do
  @moduledoc """
  Helpers for working with absinthe subscriptions
  """

  import AshGraphql.ContextHelpers

  @doc """
  Produce a query that will load the correct data for a subscription.
  """
  def query_for_subscription(query, domain, %{context: context} = resolution) do
    query
    |> Ash.Query.new()
    |> Ash.Query.set_tenant(Map.get(context, :tenant))
    |> Ash.Query.set_context(get_context(context))
    |> AshGraphql.Graphql.Resolver.select_fields(query.resource, resolution, nil)
    |> AshGraphql.Graphql.Resolver.load_fields(
      [
        domain: domain,
        tenant: Map.get(context, :tenant),
        authorize?: AshGraphql.Domain.Info.authorize?(domain),
        actor: Map.get(context, :actor)
      ],
      query.resource,
      resolution,
      resolution.path,
      context
    )
  end
end
