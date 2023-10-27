defmodule AshGraphql.Subscription do
  @moduledoc """
  Helpers for working with absinthe subscriptions
  """

  import AshGraphql.ContextHelpers

  @doc """
  Produce a query that will load the correct data for a subscription.
  """
  def query_for_subscription(query, api, %{context: context} = resolution) do
    query = Ash.Query.to_query(query)

    query
    |> Ash.Query.set_tenant(Map.get(context, :tenant))
    |> Ash.Query.set_context(get_context(context))
    |> AshGraphql.Graphql.Resolver.select_fields(query.resource, resolution)
    |> AshGraphql.Graphql.Resolver.load_fields(
      [
        api: api,
        tenant: Map.get(context, :tenant),
        authorize?: AshGraphql.Api.Info.authorize?(api),
        actor: Map.get(context, :actor)
      ],
      query.resource,
      resolution,
      resolution.path,
      context
    )
  end
end
