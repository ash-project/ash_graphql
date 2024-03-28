defmodule AshGraphql.Test.RootLevelErrorsSchema do
  @moduledoc false

  use Absinthe.Schema

  @domains [AshGraphql.Test.RootLevelErrorsDomain]

  use AshGraphql, domains: @domains

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
