# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.EnumNewType do
  @moduledoc false
  use Ash.Type.Enum, values: [:biz, :buz]

  def graphql_type(_), do: :biz_buz
end
