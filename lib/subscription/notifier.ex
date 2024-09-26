defmodule AshGraphql.Subscription.Notifier do
  alias AshGraphql.Resource.Info
  use Ash.Notifier

  @impl Ash.Notifier
  def notify(notification) do
    pub_sub = Info.subscription_pubsub(notification.resource)

    for subscription <- AshGraphql.Resource.Info.subscriptions(notification.resource) do
      if notification.action.name in List.wrap(subscription.actions) or
           notification.action.type in List.wrap(subscription.action_types) do
        Absinthe.Subscription.publish(pub_sub, notification, [{subscription.name, "*"}])
      end
    end

    :ok
  end
end
