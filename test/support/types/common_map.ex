# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.CommonMap do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        some: [
          type: :string,
          allow_nil?: false
        ],
        stuff: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :common_map

  @impl true
  def graphql_input_type(_), do: :common_map_input
end
