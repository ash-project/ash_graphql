defmodule AshGraphql.Resource.Subscription.Notifier do
  alias AshGraphql.Resource.Info
  use Ash.Notifier

  @impl Ash.Notifier
  def notify(notification) do
    pub_sub = Info.subscription_pubsub(notification.resource)

    for subscription <- AshGraphql.Resource.Info.subscriptions(notification.resource) do
      Absinthe.Subscription.publish(pub_sub, notification.data, [{subscription.name, "*"}])
    end
  end
end
