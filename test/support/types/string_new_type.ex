# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.StringNewType do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :string, constraints: [match: "hello"]
end
