# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelaySchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.RelayDomain]

  use AshGraphql,
    domains: @domains,
    relay_ids?: true,
    generate_sdl_file: "priv/schema-relay.graphql"

  query do
  end

  mutation do
  end

  subscription do
  end
end
