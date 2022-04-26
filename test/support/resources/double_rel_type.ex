defmodule AshGraphql.Test.DoubleRelType do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :first,
      :second
    ]

  def graphql_type, do: :double_rel_type
end
