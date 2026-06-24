# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RootLevelErrorsSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.RootLevelErrorsDomain]

  use AshGraphql, domains: @domains, generate_sdl_file: "priv/root_level_errors.graphql"
  import_types(AshGraphql.Test.SchemaTypes)

  query do
  end

  mutation do
  end
end
