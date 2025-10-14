# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Graphql.DomainMiddleware do
  @moduledoc false
  def set_domain(resolution, domain) do
    Map.update!(resolution, :context, &Map.put(&1, :domain, domain))
  end
end
