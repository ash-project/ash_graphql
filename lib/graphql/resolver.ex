defmodule AshGraphql.Graphql.Resolver do
  def resolve(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :get, action}
      ) do
    opts =
      if api.graphql_authorize?() do
        [actor: Map.get(context, :actor), action: action]
      else
        [action: action]
      end

    result = api.get(resource, id, opts)

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: %{limit: limit, offset: offset}, context: context} = resolution,
        {api, resource, :read, action}
      ) do
    opts =
      if api.graphql_authorize?() do
        [actor: Map.get(context, :actor), action: action]
      else
        [action: action]
      end

    result =
      resource
      |> api.query
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)
      |> api.read(opts)
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
