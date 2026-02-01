# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.StringNewType do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :string, constraints: [match: "hello"]
end
