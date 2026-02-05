# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.Schema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ResponseMetadata.Domain]

  use AshGraphql,
    domains: @domains,
    response_metadata: :metadata

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  query do
    field :say_hello, :string do
      resolve(fn _, _, _ ->
        {:ok, "Hello!"}
      end)
    end

    field :complex_query, list_of(:string) do
      arg(:count, non_null(:integer))

      resolve(fn %{count: count}, _ ->
        {:ok, Enum.map(1..count, &"Item #{&1}")}
      end)
    end
  end

  mutation do
  end

  subscription do
  end
end
