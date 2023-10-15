defmodule AshGraphql.Test.Schema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.Domain, AshGraphql.Test.OtherDomain]

  use AshGraphql, domains: @domains, generate_sdl_file: "priv/schema.graphql"

  alias AshGraphql.Test.Post

  require Ash.Query

  query do
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
    field :post_created, :post do
      config(fn
        _args, %{context: %{actor: %{id: user_id}}} ->
          {:ok, topic: user_id, context_id: "user/#{user_id}"}

        _args, _context ->
          {:error, :unauthorized}
      end)

      resolve(fn args, _, resolution ->
        # loads all the data you need
        AshGraphql.Subscription.query_for_subscription(
          Post,
          Api,
          resolution
        )
        |> Ash.Query.filter(id == ^args.id)
        |> Ash.read(actor: resolution.context.current_user)
      end)
    end
  end
end
