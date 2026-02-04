# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.CustomHandlerSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.ResponseMetadata.CustomDomain]

  use AshGraphql,
    domains: @domains,
    response_metadata: {:metadata, {__MODULE__, :build_custom_metadata, []}}

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  def build_custom_metadata(info) do
    %{
      complexity: info.complexity,
      duration_ms: info.duration_ms,
      custom_field: "custom_value"
    }
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
