# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.NewTypeWithDescription do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        value: [type: :string, allow_nil?: false]
      ]
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :new_type_with_description

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :new_type_with_description_input

  @impl AshGraphql.Type
  def graphql_description(_), do: "A described NewType"
end
