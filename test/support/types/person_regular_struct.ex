# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.PersonRegularStruct do
  @moduledoc false

  use Ash.Type.NewType,
    subtype_of: :struct,
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
  def graphql_type(_), do: :person_regular_type

  @impl true
  def graphql_input_type(_), do: :person_regular_input_type
end
