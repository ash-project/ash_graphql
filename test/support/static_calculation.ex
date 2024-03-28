defmodule AshGraphql.Test.StaticCalculation do
  @moduledoc false
  use Ash.Resource.Calculation, type: :string

  def calculate(records, _, _) do
    Enum.map(records, fn _ -> "static" end)
  end
end
