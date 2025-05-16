defmodule AshGraphql.Graphql.ContextMiddleware do
  @moduledoc false

  def extend_context(resolution, extend_context) do
    Map.update!(resolution, :context, &Map.merge(&1, extend_context))
  end
end
