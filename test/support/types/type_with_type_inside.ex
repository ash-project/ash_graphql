# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.TypeWithTypeInside do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        inner_type: [
          type: AshGraphql.Test.TypeWithinTypeUnreferencedSubmap,
          allow_nil?: false
        ],
        another_field: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :type_with_type_inside

  @impl true
  def graphql_input_type(_), do: :type_with_type_inside_input
end
