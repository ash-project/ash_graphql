# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Functions.TestILike do
  @moduledoc false
  use Ash.Query.Function, name: :ilike, predicate?: true

  def args, do: [[:string, :string]]
end
