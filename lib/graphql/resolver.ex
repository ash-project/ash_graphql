defmodule AshGraphql.Graphql.Resolver do
  def resolve(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :get, action}
      ) do
    result =
      api.get(resource, id,
        action: action,
        authorize?: api.graphql_authorize?,
        actor: Map.get(context, :actor)
      )

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: %{limit: limit, offset: offset}, context: context} = resolution,
        {api, resource, :read, action}
      ) do
    result =
      resource
      |> api.query
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)
      |> api.read(
        action: action,
        actor: Map.get(context, :actor),
        authorize?: api.graphql_authorize?()
      )
      |> case do
        {:ok, results} ->
          {:ok, %AshGraphql.Paginator{results: results, limit: limit, offset: offset}}

        error ->
          error
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(resolution, _),
    do: Absinthe.Resolution.put_result(resolution, {:error, :unknown_request})

  defp to_resolution({:ok, value}), do: {:ok, value}
  defp to_resolution({:error, error}), do: {:error, List.wrap(error)}
end
