# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.StaticCalculation do
  @moduledoc false
  use Ash.Resource.Calculation, type: :string

  def calculate(records, _, _) do
    Enum.map(records, fn _ -> "static" end)
  end
end
