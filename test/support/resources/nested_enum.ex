# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.NestedEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:foo, :bar]

  def graphql_type(_), do: :nested_enum
end
