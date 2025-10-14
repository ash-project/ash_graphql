# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ConstrainedMap do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        foo_bar: [
          type: :string,
          allow_nil?: false
        ],
        baz: [
          type: :integer
        ],
        bam: [
          type: :map,
          constraints: [
            fields: [
              qux: [
                type: :string
              ]
            ]
          ]
        ]
      ]
    ]

  def graphql_type(_), do: :constrained_map
  def graphql_input_type(_), do: :constrained_map_input
end
