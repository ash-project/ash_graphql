# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.QueryGroup do
  @moduledoc false
  defstruct [:name, :__identifier__, :__spark_metadata__, queries: []]
end
