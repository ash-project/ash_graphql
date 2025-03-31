defmodule AshGraphql.Test.PageOfFilterByActorChannelMessagesCalculation do
  @moduledoc false
  use Ash.Resource.Calculation

  def load(_, _, context) do
    limit = context.arguments.limit || 10
    offset = context.arguments.offset || 0

    [
      :filter_by_user_channel_message_count,
      filter_by_actor_messages:
        AshGraphql.Test.Message
        |> Ash.Query.limit(limit)
        |> Ash.Query.offset(offset)
        |> Ash.Query.select([:type, :text])
    ]
  end

  def calculate([channel], _, context) do
    limit = context.arguments.limit || 10
    offset = context.arguments.offset || 0

    {:ok,
     [
       %{
         count: channel.filter_by_user_channel_message_count,
         has_next_page: channel.filter_by_user_channel_message_count > offset + limit,
         results:
           channel.filter_by_actor_messages
           |> Enum.map(
             &%Ash.Union{type: AshGraphql.Test.MessageUnion.struct_to_name(&1), value: &1}
           )
       }
     ]}
  end
end
