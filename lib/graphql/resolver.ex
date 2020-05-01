defmodule AshGraphql.Graphql.Resolver do
  def resolve(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :get, action}
      ) do
    result =
      if api.graphql_authorize?() do
        api.get(resource, id, action: action, authorization: [user: Map.get(context, :user)])
      else
        api.get(resource, id, action: action)
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: %{limit: limit, offset: offset}, context: context} = resolution,
        {api, resource, :read, action}
      ) do
    result =
      if api.graphql_authorize?() do
        api.read(resource,
          page: [limit: limit, offset: offset],
          action: action,
          authorization: [user: Map.get(context, :user)]
        )
      else
        api.read(resource, page: [limit: limit, offset: offset], action: action)
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(resolution, _),
    do: Absinthe.Resolution.put_result(resolution, {:error, :unknown_request})

  defp to_resolution({:ok, value}), do: {:ok, value}
  defp to_resolution({:error, error}), do: {:error, List.wrap(error)}
end
