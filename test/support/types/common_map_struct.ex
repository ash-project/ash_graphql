# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.CommonMapStruct do
  defstruct [:some, :stuff]
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :struct,
    constraints: [
      instance_of: __MODULE__,
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
  def graphql_type(_), do: :common_map_struct

  @impl true
  def graphql_input_type(_), do: :common_map_struct_input
end
