# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Types.SimpleUnion do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        int: [
          type: :integer
        ],
        string: [
          type: :string
        ]
      ]
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :simple_union
end
