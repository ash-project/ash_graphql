defmodule AshGraphql.Test.Schema do
  @moduledoc false

  use Absinthe.Schema

  @apis [AshGraphql.Test.Api]

  alias AshGraphql.Test.Api
  alias AshGraphql.Test.Post
  use AshGraphql, apis: @apis

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
end
