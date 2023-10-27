defmodule AshGraphql.SubscriptionTest do
  use ExUnit.Case

  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.Schema

  setup_all do
    Application.put_env(PubSub, :notifier_test_pid, self())
    {:ok, _} = PubSub.start_link()
    {:ok, _} = Absinthe.Subscription.start_link(PubSub)
    :ok
  end

  @query """
  subscription {
    subscribableCreated { id }
  }
  """
  @tag :wip
  test "subscription triggers work" do
    id = "1"

    assert {:ok, %{"subscribed" => topic}} =
             run_subscription(
               @query,
               Schema,
               variables: %{"userId" => id},
               context: %{pubsub: PubSub, actor: %{id: id}}
             )

    PubSub.subscribe("subscribable:created")

    mutation = """
    mutation CreateSubscribable($input: CreateSubscribableInput) {
        createSubscribable(input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
    """

    assert {:ok, %{data: data}} =
             run_subscription(mutation, Schema,
               variables: %{"input" => %{"text" => "foo"}},
               context: %{pubsub: PubSub}
             )

    assert_receive({:broadcast, msg})

    Absinthe.Subscription.publish(PubSub, data, subscribable_created: nil)
    |> IO.inspect(label: :publish)

    assert %{
             event: "subscription:data",
             result: %{data: %{"user" => %{"id" => "1", "name" => "foo"}}},
             topic: topic
           } == msg
  end

  defp run_subscription(query, schema, opts) do
    opts = Keyword.update(opts, :context, %{pubsub: PubSub}, &Map.put(&1, :pubsub, PubSub))

    case Absinthe.run(query, schema, opts) |> IO.inspect(label: :absinthe_run) do
      {:ok, %{"subscribed" => topic}} = val ->
        PubSub.subscribe(topic)
        val

      val ->
        val
    end
  end
end
