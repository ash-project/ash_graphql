defmodule GF.Types.MemberStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:non_member, :inactive, :active, :banned]

  def graphql_type(_), do: :sample_member_status
  def graphql_input_type(_), do: :sample_member_status
end
