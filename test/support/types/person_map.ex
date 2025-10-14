# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.PersonMap do
  @moduledoc false

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        name: [
          type: :string,
          allow_nil?: false
        ],
        age: [
          type: :integer,
          allow_nil?: true
        ],
        email: [
          type: :string,
          allow_nil?: true
        ]
      ]
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :person_map_type

  @impl true
  def graphql_input_type(_), do: :person_map_input_type
end
