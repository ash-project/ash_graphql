defmodule AshGraphql.Subscription.Notifier do
  @moduledoc """
  AshNotifier that triggers absinthe if subscriptions are listening
  """
  use Ash.Notifier

  alias AshGraphql.Resource.Info
  alias AshGraphql.Subscription.Batcher.Notification

  @impl Ash.Notifier
  def notify(%Ash.Notifier.Notification{} = notification) do
    pub_sub = Info.subscription_pubsub(notification.resource)

    for subscription <-
          AshGraphql.Resource.Info.subscriptions(notification.resource, notification.domain) do
      if notification.action.name in List.wrap(subscription.actions) or
           notification.action.type in List.wrap(subscription.action_types) do
        Absinthe.Subscription.publish(
          pub_sub,
          %Notification{action_type: notification.action.type, data: notification.data},
          [{subscription.name, "*"}]
        )
      end
    end

    :ok
  end
end
