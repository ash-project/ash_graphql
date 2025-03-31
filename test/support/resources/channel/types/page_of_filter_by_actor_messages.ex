defmodule AshGraphql.Test.PageOfFilterByActorChannelMessages do
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
  def graphql_type(_), do: :filter_by_actor_channel_messages

  @impl true
  def graphql_input_type(_), do: :filter_by_actor_channel_messages
end
