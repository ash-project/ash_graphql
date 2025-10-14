# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Schema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.Domain, AshGraphql.Test.OtherDomain]

  use AshGraphql, domains: @domains, generate_sdl_file: "priv/schema.graphql"

  def middleware(middleware, _field, %Absinthe.Type.Object{identifier: identifier})
      when identifier in [:query, :mutation, :subscription] do
    middleware ++ [AshGraphql.MetaMiddleware]
  end

  def middleware(middleware, _field, _object) do
    middleware
  end

  query do
    field :custom_get_post, :post do
      arg(:id, non_null(:id))

      resolve(fn %{id: post_id}, resolution ->
        with {:ok, post} when not is_nil(post) <- Ash.get(AshGraphql.Test.Post, post_id) do
          post
          |> AshGraphql.load_fields(AshGraphql.Test.Post, resolution)
        end
        |> AshGraphql.handle_errors(AshGraphql.Test.Post, resolution)
      end)
    end

    field :custom_get_post_query, :post do
      arg(:id, non_null(:id))

      resolve(fn %{id: post_id}, resolution ->
        AshGraphql.Test.Post
        |> Ash.Query.do_filter(id: post_id)
        |> AshGraphql.load_fields_on_query(resolution)
        |> Ash.read_one(not_found_error?: true)
        |> AshGraphql.handle_errors(AshGraphql.Test.Post, resolution)
      end)
    end
  end

  mutation do
  end

  object :foo do
    field(:foo, :string)
    field(:bar, :string)
  end

  input_object :foo_input do
    field(:foo, non_null(:string))
    field(:bar, non_null(:string))
  end

  enum :status do
    value(:open, description: "The post is open")
    value(:closed, description: "The post is closed")
  end

  subscription do
  end
end
