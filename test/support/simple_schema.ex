# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule SimpleSchema do
  @moduledoc false
  # Used for simple one-off manual tests

  use Absinthe.Schema

  # This is used situationally to define single actions
  # and types in, to avoid the complexity of the other
  # schemas that define a lot of types and actions etc.
  # This should be cleared out and assertions should be done
  # against other schemas
  @domains [AshGraphql.Test.SimpleDomain]

  use AshGraphql,
    domains: @domains,
    relay_ids?: true,
    generate_sdl_file: "priv/schema-relay.graphql"

  query do
    field :say_hello, :string do
      resolve(fn _, _, _ ->
        {:ok, "Hello from AshGraphql!"}
      end)
    end
  end

  mutation do
  end

  subscription do
  end
end
