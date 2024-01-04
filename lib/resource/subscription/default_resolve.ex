defmodule AshGraphql.Resource.Subscription.DefaultResolve do
  require Ash.Query

  def resolve(args, _, resolution) do
    AshGraphql.Subscription.query_for_subscription(
      Post,
      Api,
      resolution
    )
    |> Ash.Query.filter(id == ^args.id)
    |> Api.read(actor: resolution.context.current_user)
  end
end
