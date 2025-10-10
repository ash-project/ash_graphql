# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.NestedEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [:foo, :bar]

  def graphql_type(_), do: :nested_enum
end
