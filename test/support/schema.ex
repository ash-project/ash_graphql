defmodule AshGraphql.Test.Schema do
  @moduledoc false

  use Absinthe.Schema

  @apis [AshGraphql.Test.Api]

  use AshGraphql, apis: @apis

  query do
  end

  mutation do
  end

  def context(ctx) do
    AshGraphql.add_context(ctx, @apis)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
