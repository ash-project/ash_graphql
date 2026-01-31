# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.DisabledSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ResponseMetadata.DisabledDomain]

  use AshGraphql,
    domains: @domains,
    response_metadata: false

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  query do
    field :say_hello, :string do
      resolve(fn _, _, _ ->
        {:ok, "Hello!"}
      end)
    end
  end

  mutation do
  end

  subscription do
  end
end
