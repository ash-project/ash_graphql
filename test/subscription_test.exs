defmodule AshGraphql.SubscriptionTest do
  use ExUnit.Case

  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.Schema

  setup do
    Application.put_env(PubSub, :notifier_test_pid, self())
    {:ok, _} = PubSub.start_link()
    {:ok, _} = Absinthe.Subscription.start_link(PubSub)
    :ok
  end

  @query """
  subscription {
    subscribableCreated {
      created {
        id
      }
    }
  }
  """
  @tag :wip
  test "can subscribe to a resource" do
    id = "1"

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               @query,
               Schema,
               variables: %{"userId" => id},
               context: %{actor: %{id: id}, pubsub: PubSub}
             )

    mutation = """
    mutation CreateSubscribable($input: CreateSubscribableInput) {
        createSubscribable(input: $input) {
          result{
            id
            text
          }
          errors{
            message
          }
        }
      }
    """

    assert {:ok, %{data: data}} =
             Absinthe.run(mutation, Schema, variables: %{"input" => %{"text" => "foo"}})

    assert Enum.empty?(data["createSubscribable"]["errors"])

    assert_receive({^topic, data})

    assert data["createSubscribable"]["result"]["id"] ==
             data["subscribableCreated"]["created"]["id"]
  end
end
