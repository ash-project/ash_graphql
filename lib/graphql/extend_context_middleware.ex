defmodule AshGraphql.Graphql.ExtendContextMiddleware do
  @moduledoc false

  def extend_context(resolution, extend_context) do
    IO.inspect(resolution)
    IO.inspect(extend_context)

    Map.update!(resolution, :context, &Map.merge(&1, extend_context))
  end
end
