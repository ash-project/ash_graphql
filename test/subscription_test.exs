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
    start_supervised(AshGraphql.Subscription.Batcher, [])
    :ok

    on_exit(fn ->
      Application.delete_env(:ash_graphql, :simulate_subscription_processing_time)
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

    AshGraphql.Subscription.Batcher.drain()

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

    AshGraphql.Subscription.Batcher.drain()

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

    AshGraphql.Subscription.Batcher.drain()

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

    AshGraphql.Subscription.Batcher.drain()

    assert_receive {^topic1, %{data: subscription_data}}

    assert subscribable.id ==
             subscription_data["dedupedSubscribableEvents"]["created"]["id"]
  end

  test "can subscribe to read actions that take arguments" do
    actor1 = %{
      id: 1,
      role: :user
    }

    subscription = """
    subscription WithArguments($topic: String!) {
      subscribableEventsWithArguments(topic: $topic) {
        created {
          id
          text
        }
      }
    }
    """

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               subscription,
               Schema,
               variables: %{"topic" => "news"},
               context: %{actor: actor1, pubsub: PubSub}
             )

    subscribable =
      Subscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", topic: "news", actor_id: 1},
        actor: @admin
      )
      |> Ash.create!()

    AshGraphql.Subscription.Batcher.drain()

    assert_receive {^topic, %{data: subscription_data}}

    assert subscribable.id ==
             subscription_data["subscribableEventsWithArguments"]["created"]["id"]
  end

  test "can subscribe on the domain" do
    actor1 = %{
      id: 1,
      role: :user
    }

    subscription = """
    subscription {
      subscribedOnDomain {
        created {
          id
          text
        }
      }
    }
    """

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               subscription,
               Schema,
               context: %{actor: actor1, pubsub: PubSub}
             )

    subscribable =
      Subscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", topic: "news", actor_id: 1},
        actor: @admin
      )
      |> Ash.create!()

    AshGraphql.Subscription.Batcher.drain()

    assert_receive {^topic, %{data: subscription_data}}

    assert subscribable.id ==
             subscription_data["subscribedOnDomain"]["created"]["id"]
  end

  test "can not see forbidden field" do
    actor1 = %{
      id: 1,
      role: :user
    }

    subscription = """
    subscription {
      subscribedOnDomain {
        created {
          id
          text
          hiddenField
        }
      }
    }
    """

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               subscription,
               Schema,
               context: %{actor: actor1, pubsub: PubSub}
             )

    Subscribable
    |> Ash.Changeset.for_create(:create, %{text: "foo", topic: "news", actor_id: 1},
      actor: @admin
    )
    |> Ash.create!()

    AshGraphql.Subscription.Batcher.drain()

    assert_receive {^topic, %{data: subscription_data, errors: errors}}

    assert is_nil(subscription_data["subscribedOnDomain"]["created"])
    refute Enum.empty?(errors)
    assert [%{code: "forbidden_field"}] = errors
  end

  test "it aggregates multiple messages" do
    stop_supervised(AshGraphql.Subscription.Batcher)
    start_supervised({AshGraphql.Subscription.Batcher, [async_threshold: 0]})

    Application.put_env(:ash_graphql, :simulate_subscription_processing_time, 1000)

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

    subscribable_id = mutation_result["createSubscribable"]["result"]["id"]

    assert {:ok, %{data: mutation_result}} =
             Absinthe.run(create_mutation, Schema,
               variables: %{"input" => %{"text" => "foo"}},
               context: %{actor: @admin}
             )

    assert GenServer.call(AshGraphql.Subscription.Batcher, :dump_state, :infinity).total_count ==
             2

    assert Enum.empty?(mutation_result["createSubscribable"]["errors"])

    subscribable_id2 = mutation_result["createSubscribable"]["result"]["id"]
    refute is_nil(subscribable_id)

    assert_receive({^topic, %{data: subscription_data}})
    assert_receive({^topic, %{data: subscription_data2}})
    refute_received({^topic, _})

    assert subscribable_id ==
             subscription_data["subscribableEvents"]["created"]["id"]

    assert subscribable_id2 ==
             subscription_data2["subscribableEvents"]["created"]["id"]
  end
end
