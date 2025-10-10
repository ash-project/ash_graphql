# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.StatusEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:open, :closed]

  def graphql_type(_), do: :status_enum
end
