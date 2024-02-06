defmodule AshGraphql.Resource.Subscription.DefaultResolve do
  require Ash.Query

  def resolve(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {api, resource, %AshGraphql.Resource.Subscription{}, input?}
      ) do
    result =
      AshGraphql.Subscription.query_for_subscription(
        resource,
        api,
        resolution
      )
      # |> Ash.Query.filter(id == ^args.id)
      |> Ash.Query.limit(1)
      |> api.read_one(actor: resolution.context[:current_user])

    resolution
    |> Absinthe.Resolution.put_result(result)
  end
end
