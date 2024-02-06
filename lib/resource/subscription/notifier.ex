defmodule AshGraphq.Resource.Subscription.Notifier do
  use Ash.Notifier

  @impl Ash.Notifier
  def notify(notification) do
    IO.inspect(notification, label: :Notifier)

    Absinthe.Subscription.publish(AshGraphql.Test.PubSub, notification.data,
      subscrible_created: "*"
    )
  end
end
