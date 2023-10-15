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
    post_created { id }
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

    mutation = """
    mutation SimpleCreatePost($input: SimpleCreatePostInput) {
        simpleCreatePost(input: $input) {
          result{
            text1
            integerAsStringInApi
          }
          errors{
            message
          }
        }
      }
    """

    assert {:ok, %{data: _}} =
             run_subscription(mutation, Schema,
               variables: %{"input" => %{"text1" => "foo", "integerAsStringInApi" => "1"}},
               context: %{pubsub: PubSub}
             )

    assert_receive({:broadcast, msg})

    assert %{
             event: "subscription:data",
             result: %{data: %{"user" => %{"id" => "1", "name" => "foo"}}},
             topic: topic
           } == msg
  end

  defp run_subscription(query, schema, opts) do
    opts = Keyword.update(opts, :context, %{pubsub: PubSub}, &Map.put(&1, :pubsub, PubSub))

    case Absinthe.run(query, schema, opts) do
      {:ok, %{"subscribed" => topic}} = val ->
        PubSub.subscribe(topic)
        val

      val ->
        val
    end
  end
end
