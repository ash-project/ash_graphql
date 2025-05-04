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
