# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.SimpleResource do
  @moduledoc false
  # Used for simple one-off manual tests
  use Ash.Resource,
    extensions: [AshGraphql.Resource],
    domain: AshGraphql.Test.SimpleDomain
end
