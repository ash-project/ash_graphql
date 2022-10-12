defmodule AshGraphql.Test.Schema do
  @moduledoc false

  use Absinthe.Schema

  @apis [{AshGraphql.Test.Api, AshGraphql.Test.Registry}]

  use AshGraphql, apis: @apis

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

  def context(ctx) do
    AshGraphql.add_context(ctx, @apis)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
