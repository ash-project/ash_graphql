# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.StatusEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:open, :closed]

  def graphql_type(_), do: :status_enum
end
