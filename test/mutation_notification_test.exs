# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MutationNotificationTest do
  @moduledoc """
  Tests that GraphQL mutations don't strip attributes from Ash notification data.

  When a GraphQL mutation requests only a subset of fields (e.g. `{ id }`), the
  notification data sent to Ash notifiers should still include all `select_by_default`
  attributes. Previously, AshGraphQL passed a restricted `select` based on the GraphQL
  query fields, which caused Ash to mask unrequested attributes with `%Ash.NotLoaded{}`.
  This broke downstream notification consumers (PubSub subscribers, GenServers) that
  relied on attributes like foreign keys.
  """
  use ExUnit.Case, async: false

  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.Schema

  @admin %{id: Ash.UUID.generate(), role: :admin}

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  setup do
    Application.put_env(:ash_graphql, :notification_spy_pid, self())
    Application.put_env(PubSub, :notifier_test_pid, self())
    {:ok, pubsub} = PubSub.start_link()
    {:ok, absinthe_sub} = Absinthe.Subscription.start_link(PubSub)
    start_supervised(AshGraphql.Subscription.Batcher, [])

    on_exit(fn ->
      Application.delete_env(:ash_graphql, :notification_spy_pid)
      Process.exit(pubsub, :normal)
      Process.exit(absinthe_sub, :normal)
      assert_down(pubsub)
      assert_down(absinthe_sub)

      try do
        AshGraphql.TestHelpers.stop_ets()
      rescue
        _ -> :ok
      end
    end)
  end

  describe "notification data from mutations includes all default attributes" do
    test "create mutation notification has belongs_to foreign key loaded" do
      actor =
        AshGraphql.Test.Actor
        |> Ash.Changeset.for_create(:create, %{name: "test_actor"})
        |> Ash.create!()

      resp =
        """
        mutation CreateSubscribable($input: CreateSubscribableInput) {
          createSubscribable(input: $input) {
            result { id }
            errors { message }
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{"input" => %{"text" => "hello", "actorId" => actor.id}},
          context: %{actor: @admin}
        )

      assert {:ok, %{data: %{"createSubscribable" => %{"errors" => []}}}} = resp

      assert_receive {:ash_notification, notification}, 1000
      assert notification.data.actor_id == actor.id
      refute match?(%Ash.NotLoaded{}, notification.data.text)
    end

    test "update mutation notification has belongs_to foreign key loaded when not queried" do
      actor =
        AshGraphql.Test.Actor
        |> Ash.Changeset.for_create(:create, %{name: "test_actor"})
        |> Ash.create!()

      subscribable =
        AshGraphql.Test.Subscribable
        |> Ash.Changeset.for_create(:create, %{text: "hello", actor_id: actor.id})
        |> Ash.create!(authorize?: false)

      # Drain the create notification
      assert_receive {:ash_notification, _create_notification}, 1000

      # Mutation requests ONLY `id` — does not request actorId or text
      resp =
        """
        mutation UpdateSubscribable($id: ID!, $input: UpdateSubscribableInput) {
          updateSubscribable(id: $id, input: $input) {
            result { id }
            errors { message }
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{
            "id" => subscribable.id,
            "input" => %{"text" => "updated"}
          },
          context: %{actor: @admin}
        )

      assert {:ok, %{data: %{"updateSubscribable" => %{"errors" => []}}}} = resp

      # Notification data should have ALL select_by_default attributes loaded,
      # not just the ones requested in the GraphQL response
      assert_receive {:ash_notification, notification}, 1000
      assert notification.data.actor_id == actor.id
      assert notification.data.text == "updated"
      refute match?(%Ash.NotLoaded{}, notification.data.actor_id)
    end

    test "update mutation response only includes queried fields" do
      subscribable =
        AshGraphql.Test.Subscribable
        |> Ash.Changeset.for_create(:create, %{text: "hello"})
        |> Ash.create!(authorize?: false)

      resp =
        """
        mutation UpdateSubscribable($id: ID!, $input: UpdateSubscribableInput) {
          updateSubscribable(id: $id, input: $input) {
            result { id }
            errors { message }
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{
            "id" => subscribable.id,
            "input" => %{"text" => "updated"}
          },
          context: %{actor: @admin}
        )

      assert {:ok, %{data: %{"updateSubscribable" => %{"errors" => [], "result" => result}}}} =
               resp

      # Response should only contain the queried field
      assert Map.keys(result) == ["id"]
    end

    test "destroy mutation notification has attributes loaded" do
      actor =
        AshGraphql.Test.Actor
        |> Ash.Changeset.for_create(:create, %{name: "test_actor"})
        |> Ash.create!()

      subscribable =
        AshGraphql.Test.Subscribable
        |> Ash.Changeset.for_create(:create, %{text: "hello", actor_id: actor.id})
        |> Ash.create!(authorize?: false)

      resp =
        """
        mutation DestroySubscribable($id: ID!) {
          destroySubscribable(id: $id) {
            result { id }
            errors { message }
          }
        }
        """
        |> Absinthe.run(Schema,
          variables: %{"id" => subscribable.id},
          context: %{actor: @admin}
        )

      assert {:ok, %{data: %{"destroySubscribable" => %{"errors" => []}}}} = resp

      assert_receive {:ash_notification, notification}, 1000
      assert notification.data.actor_id == actor.id
      refute match?(%Ash.NotLoaded{}, notification.data.text)
    end
  end
end
