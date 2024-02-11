defmodule AshGraphql.Graphql.ApiMiddleware do
  def set_api(resolution, api) do
    Map.update!(resolution, :context, &Map.put(&1, :api, api))
  end
end
