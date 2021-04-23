defmodule AshGraphql.Test.StatusEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:open, :closed]

  def graphql_type, do: :status_enum
end
