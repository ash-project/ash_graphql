defmodule AshGraphql.Types.EnumNewType do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :atom, constraints: [one_of: [:biz, :buz]]

  def graphql_type, do: :biz_buz
end
