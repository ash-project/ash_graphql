# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Graphql.MetadataMiddleware do
  @moduledoc false
  def set_metadata(resolution, metadata) do
    Map.update!(resolution, :context, &Map.put(&1, :meta, metadata || []))
  end
end
