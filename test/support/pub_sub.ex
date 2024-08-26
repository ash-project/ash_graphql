defmodule AshGraphql.Test.PubSub do
  @behaviour Absinthe.Subscription.Pubsub

  def start_link() do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  def node_name() do
    Atom.to_string(node())
  end

  def subscribe(_topic) do
    :ok
  end

  defdelegate run_docset(pubsub, docs_and_topics, mutation_result),
    to: AshGraphql.Subscription.Runner

  def publish_subscription(topic, data) do
    send(
      Application.get_env(__MODULE__, :notifier_test_pid),
      {topic, data}
    )

    :ok
  end

  def publish_mutation(_proxy_topic, _mutation_result, _subscribed_fields) do
    :ok
  end
end
