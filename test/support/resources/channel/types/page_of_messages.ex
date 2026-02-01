# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.PageOfChannelMessages do
  @moduledoc false

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        count: [
          type: :integer,
          allow_nil?: false
        ],
        has_next_page: [
          type: :boolean,
          allow_nil?: false
        ],
        results: [
          type: {:array, AshGraphql.Test.MessageUnion},
          allow_nil?: false
        ]
      ]
    ]

  @impl true
  def graphql_type(_), do: :indirect_channel_messages

  @impl true
  def graphql_input_type(_), do: :indirect_channel_messages
end
