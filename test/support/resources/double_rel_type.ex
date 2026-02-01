# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.DoubleRelType do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :first,
      :second
    ]

  def graphql_type(_), do: :double_rel_type
end
