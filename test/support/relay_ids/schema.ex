# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.Schema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.RelayIds.Domain]

  use AshGraphql, domains: @domains, relay_ids?: true, generate_sdl_file: "priv/relay_ids.graphql"
  import_types(AshGraphql.Test.SchemaTypes)

  query do
  end

  mutation do
  end
end
