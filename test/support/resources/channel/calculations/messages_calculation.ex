# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.PageOfChannelMessagesCalculation do
  @moduledoc false
  use Ash.Resource.Calculation

  def load(_, _, context) do
    limit = context.arguments.limit || 100
    offset = context.arguments.offset || 0

    [
      :channel_message_count,
      messages:
        AshGraphql.Test.Message
        |> Ash.Query.limit(limit)
        |> Ash.Query.offset(offset)
        |> Ash.Query.select([:type, :text])
    ]
  end

  def calculate([channel], _, context) do
    limit = context.arguments.limit || 100
    offset = context.arguments.offset || 0

    {:ok,
     [
       %{
         count: channel.channel_message_count,
         has_next_page: channel.channel_message_count > offset + limit,
         results:
           channel.messages
           |> Enum.map(
             &%Ash.Union{type: AshGraphql.Test.MessageUnion.struct_to_name(&1), value: &1}
           )
       }
     ]}
  end
end
