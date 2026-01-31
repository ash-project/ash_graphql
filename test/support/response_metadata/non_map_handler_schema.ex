# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.NonMapHandlerSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ResponseMetadata.NonMapDomain]

  use AshGraphql,
    domains: @domains,
    response_metadata: {__MODULE__, :return_non_map, []}

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  def return_non_map(_info) do
    {:ok, %{some: "data"}}
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
