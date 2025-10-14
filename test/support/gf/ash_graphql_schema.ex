# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.AshGraphqlSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [GF.Domain]

  use AshGraphql, domains: @domains, generate_sdl_file: "priv/gf_schema.graphql"

  query do
  end

  mutation do
  end
end
