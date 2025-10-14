# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.SubscriptionTest do
  use ExUnit.Case

  alias AshGraphql.Test.Product
  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.RelaySchema
  alias AshGraphql.Test.RelaySubscribable
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

  test "subscription to relay schema returns relay id on destroy action for multiple notifications" do
    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               """
               subscription {
                 subscribableEventsRelay {
                   created {
                     id
                     text
                   }
                   destroyed
                 }
               }
               """,
               RelaySchema,
               context: %{actor: @admin, pubsub: PubSub}
             )

    subscribable_relay_id =
      RelaySubscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", actor_id: 1}, actor: @admin)
      |> Ash.create!()
      |> AshGraphql.Resource.encode_relay_id()

    assert_receive({^topic, %{data: subscription_data}})

    assert subscribable_relay_id == subscription_data["subscribableEventsRelay"]["created"]["id"]

    destroy_mutation = """
    mutation DeleteSubscribable($id: ID!) {
        destroySubscribableRelay(id: $id) {
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
             Absinthe.run(destroy_mutation, RelaySchema,
               variables: %{"id" => subscribable_relay_id},
               context: %{actor: @admin}
             )

    assert Enum.empty?(mutation_result["destroySubscribableRelay"]["errors"])

    assert_receive({^topic, %{data: subscription_data}})

    assert subscription_data["subscribableEventsRelay"]["destroyed"] == subscribable_relay_id
  end

  test "subscription to relay schema returns relay id on destroy action for single notification" do
    subscribable_relay_id =
      RelaySubscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", actor_id: 1}, actor: @admin)
      |> Ash.create!()
      |> AshGraphql.Resource.encode_relay_id()

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               """
               subscription {
                 subscribableDeletedRelay {
                   destroyed
                 }
               }
               """,
               RelaySchema,
               context: %{actor: @admin, pubsub: PubSub}
             )

    destroy_mutation = """
    mutation DeleteSubscribable($id: ID!) {
        destroySubscribableRelay(id: $id) {
          result {
            id
          }
          errors {
            message
          }
        }
      }
    """

    assert {:ok, %{data: mutation_result}} =
             Absinthe.run(destroy_mutation, RelaySchema,
               variables: %{"id" => subscribable_relay_id},
               context: %{actor: @admin}
             )

    assert Enum.empty?(mutation_result["destroySubscribableRelay"]["errors"])

    assert_receive({^topic, %{data: subscription_data}})

    assert subscription_data["subscribableDeletedRelay"]["destroyed"] == subscribable_relay_id
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

    assert_receive {^topic, %{data: subscription_data}}

    assert subscribable.id ==
             subscription_data["subscribableEventsWithArguments"]["created"]["id"]
  end

  test "can subscribe to read actions that take arguments with relay style id's" do
    subscribable =
      RelaySubscribable
      |> Ash.Changeset.for_create(:create, %{text: "foo", topic: "news", actor_id: 1},
        actor: @admin
      )
      |> Ash.create!()

    relay_id = AshGraphql.Resource.encode_relay_id(subscribable)

    subscription = """
    subscription WithIdFilter($subscribableId: ID!) {
      subscribableEventsRelayWithIdFilter(subscribableId: $subscribableId) {
        updated {
          id
          text
        }
      }
    }
    """

    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               subscription,
               RelaySchema,
               variables: %{"subscribableId" => relay_id},
               context: %{actor: @admin, pubsub: PubSub}
             )

    update_mutation = """
    mutation UpdateSubscribable($id: ID! $input: UpdateRelaySubscribableInput) {
        updateRelaySubscribable(id: $id, input: $input) {
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

    assert {:ok, %{data: _mutation_result}} =
             Absinthe.run(update_mutation, RelaySchema,
               variables: %{"id" => relay_id, "input" => %{"text" => "updated"}},
               context: %{actor: @admin}
             )

    assert_receive({^topic, %{data: subscription_data}})

    assert relay_id ==
             subscription_data["subscribableEventsRelayWithIdFilter"]["updated"]["id"]
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

    assert_receive {^topic, %{data: subscription_data, errors: errors}}

    assert is_nil(subscription_data["subscribedOnDomain"]["created"])
    refute Enum.empty?(errors)
    assert [%{code: "forbidden_field"}] = errors
  end

  test "it aggregates multiple messages" do
    stop_supervised(AshGraphql.Subscription.Batcher)
    start_supervised({AshGraphql.Subscription.Batcher, [send_immediately_threshold: 0]})

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

    state = GenServer.call(AshGraphql.Subscription.Batcher, :dump_state, :infinity)
    assert state.total_count == 2

    assert Enum.count(state.batches) == 1

    assert Enum.empty?(mutation_result["createSubscribable"]["errors"])

    subscribable_id2 = mutation_result["createSubscribable"]["result"]["id"]
    refute is_nil(subscribable_id)

    # wait for up to 3 seconds (process timer + simulated processing time + wiggle room)
    assert_receive({^topic, %{data: subscription_data}}, 3000)
    assert_receive({^topic, %{data: subscription_data2}}, 3000)
    refute_received({^topic, _})

    assert subscribable_id ==
             subscription_data["subscribableEvents"]["created"]["id"]

    assert subscribable_id2 ==
             subscription_data2["subscribableEvents"]["created"]["id"]
  end

  test "subscription is resolved synchronously" do
    stop_supervised(AshGraphql.Subscription.Batcher)

    assert is_nil(Process.whereis(AshGraphql.Subscription.Batcher))

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

    assert_receive({^topic, %{data: subscription_data}})
    refute_received({^topic, _})

    assert subscribable_id ==
             subscription_data["subscribableEvents"]["created"]["id"]
  end

  test "can subscribe to resource with domain-level pubsub" do
    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               """
               subscription {
                 domainLevelPubsubEvents {
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
    mutation CreateDomainLevelPubsubResource($input: CreateDomainLevelPubsubResourceInput) {
        createDomainLevelPubsubResource(input: $input) {
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
               variables: %{"input" => %{"text" => "domain pubsub test"}},
               context: %{actor: @admin}
             )

    assert Enum.empty?(mutation_result["createDomainLevelPubsubResource"]["errors"])

    resource_id = mutation_result["createDomainLevelPubsubResource"]["result"]["id"]
    refute is_nil(resource_id)

    assert_receive({^topic, %{data: subscription_data}})

    assert resource_id ==
             subscription_data["domainLevelPubsubEvents"]["created"]["id"]

    assert "domain pubsub test" ==
             subscription_data["domainLevelPubsubEvents"]["created"]["text"]
  end

  test "can subscribe to resource with resource-level pubsub" do
    assert {:ok, %{"subscribed" => topic}} =
             Absinthe.run(
               """
               subscription {
                 resourceLevelPubsubEvents {
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
    mutation CreateResourceLevelPubsubResource($input: CreateResourceLevelPubsubResourceInput) {
        createResourceLevelPubsubResource(input: $input) {
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
               variables: %{"input" => %{"text" => "resource pubsub test"}},
               context: %{actor: @admin}
             )

    assert Enum.empty?(mutation_result["createResourceLevelPubsubResource"]["errors"])

    resource_id = mutation_result["createResourceLevelPubsubResource"]["result"]["id"]
    refute is_nil(resource_id)

    assert_receive({^topic, %{data: subscription_data}})

    assert resource_id ==
             subscription_data["resourceLevelPubsubEvents"]["created"]["id"]

    assert "resource pubsub test" ==
             subscription_data["resourceLevelPubsubEvents"]["created"]["text"]
  end

  test "tenant is applied to subscriptions" do
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
                 productEvents {
                   created {
                     id
                     name
                   }
                   updated {
                     id
                     name
                   }
                   destroyed
                 }
               }
               """,
               Schema,
               context: %{actor: actor1, tenant: 1, pubsub: PubSub}
             )

    assert {:ok, %{"subscribed" => topic2}} =
             Absinthe.run(
               """
               subscription {
                 productEvents {
                   created {
                     id
                     name
                   }
                   updated {
                     id
                     name
                   }
                   destroyed
                 }
               }
               """,
               Schema,
               context: %{actor: actor2, tenant: 2, pubsub: PubSub}
             )

    assert topic1 != topic2

    product =
      Product
      |> Ash.Changeset.for_create(:create, %{name: "foo"}, actor: actor1, tenant: 1)
      |> Ash.create!()

    # actor1 will get data because it can see the resource
    assert_receive {^topic1, %{data: subscription_data}}
    # actor 2 will not get data because it cannot see the resource
    refute_receive({^topic2, _})

    assert product.id ==
             subscription_data["productEvents"]["created"]["id"]
  end
end
