# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule RankedComment do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        rank: [
          type: :float,
          allow_nil?: false
        ],
        comment: [
          type: :struct,
          allow_nil?: false,
          constraints: [
            instance_of: AshGraphql.Test.Comment
          ]
        ]
      ]
    ]

  def graphql_type(_), do: :ranked_comment_result_item
end
