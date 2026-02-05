# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.EmptyMapHandlerSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ResponseMetadata.EmptyMapDomain]

  use AshGraphql,
    domains: @domains,
    response_metadata: {:metadata, {__MODULE__, :return_empty_map, []}}

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  def return_empty_map(_info) do
    %{}
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
