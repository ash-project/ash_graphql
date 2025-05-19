defmodule AshGraphql.Graphql.MetadataMiddleware do
  @moduledoc false
  def set_metadata(resolution, metadata) do
    Map.update!(resolution, :context, &Map.put(&1, :meta, metadata || []))
  end
end
