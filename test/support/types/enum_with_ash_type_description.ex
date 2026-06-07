# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.EnumWithAshTypeDescription do
  @moduledoc false
  use Ash.Type.Enum, values: [:yes, :no]
  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :enum_with_ash_type_description

  @impl AshGraphql.Type
  def graphql_description(_), do: "A yes or no type-level description"
end
