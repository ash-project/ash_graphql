defmodule AshGraphql.Test.PubSub do
  @behaviour Absinthe.Subscription.Pubsub

  def start_link() do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  def node_name() do
    node()
  end

  def subscribe(topic) do
    IO.inspect([topic: topic], label: "subscribe")
    Registry.register(__MODULE__, topic, [self()])
    :ok
  end

  def publish_subscription(topic, data) do
    message =
      %{
        topic: topic,
        event: "subscription:data",
        result: data
      }
      |> IO.inspect(label: :publish_subscription)

    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:broadcast, message})
    end)
  end

  def broadcast(topic, event, notification) do
    IO.inspect([topic: topic, event: event, notification: notification], label: "broadcast")

    message =
      %{
        topic: topic,
        event: event,
        result: notification
      }

    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:broadcast, message})
    end)
  end

  def publish_mutation(_proxy_topic, _mutation_result, _subscribed_fields) do
    # this pubsub is local and doesn't support clusters
    IO.inspect("publish mutation")
    :ok
  end
end
