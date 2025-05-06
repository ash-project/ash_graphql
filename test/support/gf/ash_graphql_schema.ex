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
