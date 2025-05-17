defmodule AshGraphql.MetaMiddleware do
  @moduledoc false
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    context = resolution.context
    meta = Map.get(context, :meta, [])

    Enum.each(meta, fn {key, value} ->
      send(self(), {:test_meta, key, value})
    end)

    resolution
  end
end
