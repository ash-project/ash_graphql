defmodule AshGraphql.Types.EnumNewType do
  @moduledoc false
  use Ash.Type.Enum, values: [:biz, :buz]

  def graphql_type(_), do: :biz_buz
end
