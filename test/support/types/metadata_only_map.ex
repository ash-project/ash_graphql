# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.MetadataOnlyMap do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        code: [
          type: :integer,
          allow_nil?: false
        ],
        message: [
          type: :string,
          allow_nil?: true
        ]
      ]
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :metadata_only_map

  @impl true
  def graphql_input_type(_), do: :metadata_only_map_input
end
