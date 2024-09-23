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
    subscribableEvents {
      created {
        id
        text
      }
      updated {
        id
        text
      }
      destroyed
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
               context: %{actor: %{id: id}, pubsub: PubSub}
             )

    create_mutation = """
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

    assert {:ok, %{data: mutation_result}} =
             Absinthe.run(create_mutation, Schema, variables: %{"input" => %{"text" => "foo"}})

    assert Enum.empty?(mutation_result["createSubscribable"]["errors"])

    subscribable_id = mutation_result["createSubscribable"]["result"]["id"]
    refute is_nil(subscribable_id)

    assert_receive({^topic, %{data: subscription_data}})

    assert subscribable_id ==
             subscription_data["subscribableEvents"]["created"]["id"]

    update_mutation = """
    mutation CreateSubscribable($id: ID! $input: UpdateSubscribableInput) {
        updateSubscribable(id: $id, input: $input) {
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

    assert {:ok, %{data: mutation_result}} =
             Absinthe.run(update_mutation, Schema,
               variables: %{"id" => subscribable_id, "input" => %{"text" => "bar"}}
             )

    assert Enum.empty?(mutation_result["updateSubscribable"]["errors"])

    assert_receive({^topic, %{data: subscription_data}})

    assert subscription_data["subscribableEvents"]["updated"]["text"] == "bar"

    destroy_mutation = """
    mutation CreateSubscribable($id: ID!) {
        destroySubscribable(id: $id) {
          result{
            id
          }
          errors{
            message
          }
        }
      }
    """

    assert {:ok, %{data: mutation_result}} =
             Absinthe.run(destroy_mutation, Schema, variables: %{"id" => subscribable_id})

    assert Enum.empty?(mutation_result["destroySubscribable"]["errors"])

    assert_receive({^topic, %{data: subscription_data}})

    assert subscription_data["subscribableEvents"]["destroyed"] == subscribable_id
  end
end
