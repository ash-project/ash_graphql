defmodule AshGraphql.SubscriptionTest do
  use ExUnit.Case

  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.Schema
  alias AshGraphql.Test.Subscribable

  def assert_down(pid) do
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, _, _, _}
  end

  setup do
    Application.put_env(PubSub, :notifier_test_pid, self())
    {:ok, pubsub} = PubSub.start_link()
    {:ok, absinthe_sub} = Absinthe.Subscription.start_link(PubSub)
    :ok

    on_exit(fn ->
      Process.exit(pubsub, :normal)
      Process.exit(absinthe_sub, :normal)
      # block until the processes have exited
      assert_down(pubsub)
      assert_down(absinthe_sub)
    end)
  end

  @admin %{
    id: 1,
    role: :admin
  }

  test "can subscribe to all action types resource" do
    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               """
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
               """,
               Schema,
               context: %{actor: @admin, pubsub: PubSub}
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
             Absinthe.run(create_mutation, Schema,
               variables: %{"input" => %{"text" => "foo"}},
               context: %{actor: @admin}
             )

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
               variables: %{"id" => subscribable_id, "input" => %{"text" => "bar"}},
               context: %{actor: @admin}
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
             Absinthe.run(destroy_mutation, Schema,
               variables: %{"id" => subscribable_id},
               context: %{actor: @admin}
             )

    assert Enum.empty?(mutation_result["destroySubscribable"]["errors"])

    assert_receive({^topic, %{data: subscription_data}})

    assert subscription_data["subscribableEvents"]["destroyed"] == subscribable_id
  end

  test "policies are applied to subscriptions" do
    actor1 = %{
      id: 1,
      role: :user
    }

    actor2 = %{
      id: 2,
      role: :user
    }

    assert {:ok, %{"subscribed" => topic1}} =
             Absinthe.run(
               """
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
               """,
               Schema,
               context: %{actor: actor1, pubsub: PubSub}
             )

    assert {:ok, %{"subscribed" => topic2}} =
             Absinthe.run(
               """
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
               """,
               Schema,
               context: %{actor: actor2, pubsub: PubSub}
             )

    assert topic1 != topic2

    subscribable =
      Subscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", actor_id: 1}, actor: @admin)
      |> Ash.create!()

    # actor1 will get data because it can see the resource
    assert_receive {^topic1, %{data: subscription_data}}
    # actor 2 will not get data because it cannot see the resource
    refute_receive({^topic2, _})

    assert subscribable.id ==
             subscription_data["subscribableEvents"]["created"]["id"]
  end

  test "can dedup with actor fun" do
    actor1 = %{
      id: 1,
      role: :user
    }

    actor2 = %{
      id: 2,
      role: :user
    }

    subscription = """
    subscription {
      dedupedSubscribableEvents {
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

    assert {:ok, %{"subscribed" => topic1}} =
             Absinthe.run(
               subscription,
               Schema,
               context: %{actor: actor1, pubsub: PubSub}
             )

    assert {:ok, %{"subscribed" => topic2}} =
             Absinthe.run(
               subscription,
               Schema,
               context: %{actor: actor2, pubsub: PubSub}
             )

    assert topic1 == topic2

    subscribable =
      Subscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", actor_id: 1}, actor: @admin)
      |> Ash.create!()

    assert_receive {^topic1, %{data: subscription_data}}

    assert subscribable.id ==
             subscription_data["dedupedSubscribableEvents"]["created"]["id"]
  end
end
