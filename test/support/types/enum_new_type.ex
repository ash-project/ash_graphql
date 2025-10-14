# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.EnumNewType do
  @moduledoc false
  use Ash.Type.Enum, values: [:biz, :buz]

  def graphql_type(_), do: :biz_buz
end
