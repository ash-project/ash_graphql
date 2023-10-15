defmodule AshGraphql.Test.PubSub do
  @behaviour Absinthe.Subscription.Pubsub

  def start_link() do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  def node_name() do
    node()
  end

  def subscribe(topic) do
    Registry.register(__MODULE__, topic, [])
    :ok
  end

  def publish_subscription(topic, data) do
    message = %{
      topic: topic,
      event: "subscription:data",
      result: data
    }

    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:broadcast, message})
    end)
  end

  def broadcast(topic, event, notification) do
    message =
      %{
        topic: topic,
        event: event,
        result: notification
      }
      |> IO.inspect(label: :message)

    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:broadcast, message})
    end)
  end

  def publish_mutation(_proxy_topic, _mutation_result, _subscribed_fields) do
    # this pubsub is local and doesn't support clusters
    :ok
  end
end
