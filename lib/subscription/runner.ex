defmodule AshGraphql.Subscription.Runner do
  @moduledoc """
  Custom implementation if the run_docset function for the PubSub module used for Subscriptions

  Mostly a copy of https://github.com/absinthe-graphql/absinthe/blob/3d0823bd71c2ebb94357a5588c723e053de8c66a/lib/absinthe/subscription/local.ex#L40
  but this lets us decide if we want to send the data to the client or not in certain error cases
  """
  require Logger

  alias AshGraphql.Subscription.Batcher
  alias Ash.Notifier

  def run_docset(pubsub, docs_and_topics, %Notifier.Notification{} = notification) do
    for {topic, key_strategy, doc} <- docs_and_topics do
      Batcher.publish(
        topic,
        %Batcher.Notification{action: notification.action, data: notification.data},
        pubsub,
        key_strategy,
        doc
      )
    end
  end
end
