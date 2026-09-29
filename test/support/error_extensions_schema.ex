# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ErrorExtensionsSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ErrorExtensionsDomain]

  use AshGraphql,
    domains: @domains,
    generate_sdl_file: false

  query do
  end

  mutation do
  end
end
