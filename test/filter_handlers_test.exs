# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.FilterHandlersTest do
  use ExUnit.Case, async: false

  alias AshGraphql.Test.PubSub
  alias AshGraphql.Test.RelayIds.{BaseImage, Schema}

  defp assert_down(pid) do
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, _, _, _}
  end

  setup do
    Application.put_env(PubSub, :notifier_test_pid, self())
    {:ok, pubsub} = PubSub.start_link()
    {:ok, absinthe_sub} = Absinthe.Subscription.start_link(PubSub)
    start_supervised(AshGraphql.Subscription.Batcher, [])

    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()

      try do
        Ash.DataLayer.Ets.stop(BaseImage)
      rescue
        _ -> :ok
      end

      Process.exit(pubsub, :normal)
      Process.exit(absinthe_sub, :normal)
      assert_down(pubsub)
      assert_down(absinthe_sub)
    end)

    :ok
  end

  describe "filter_handlers schema" do
    test "exposes integer PK id filter as GraphQL ID" do
      sdl = File.read!("priv/relay_ids.graphql")
      assert sdl =~ "input BaseImageFilterId"
      refute sdl =~ "input BaseImageFilterId {\n  eq: Int"
      assert sdl =~ "eq: ID"
    end
  end

  describe "filter_handlers queries" do
    test "list query filters by relay global id with eq" do
      image =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "hero"})
        |> Ash.create!()

      other =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "other"})
        |> Ash.create!()

      relay_id = AshGraphql.Resource.encode_relay_id(image)

      assert {:ok, result} =
               """
               query ListBaseImages($filter: BaseImageFilterInput) {
                 listBaseImages(filter: $filter) {
                   results {
                     id
                     name
                   }
                 }
               }
               """
               |> Absinthe.run(Schema, variables: %{"filter" => %{"id" => %{"eq" => relay_id}}})

      refute Map.has_key?(result, :errors)

      assert result.data["listBaseImages"]["results"] == [
               %{"id" => relay_id, "name" => "hero"}
             ]

      refute relay_id == AshGraphql.Resource.encode_relay_id(other)
    end

    test "list query filters by relay global id with in" do
      image1 =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "one"})
        |> Ash.create!()

      image2 =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "two"})
        |> Ash.create!()

      _other =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "three"})
        |> Ash.create!()

      relay_id1 = AshGraphql.Resource.encode_relay_id(image1)
      relay_id2 = AshGraphql.Resource.encode_relay_id(image2)

      assert {:ok, result} =
               """
               query ListBaseImages($filter: BaseImageFilterInput) {
                 listBaseImages(filter: $filter) {
                   results {
                     id
                     name
                   }
                 }
               }
               """
               |> Absinthe.run(Schema,
                 variables: %{"filter" => %{"id" => %{"in" => [relay_id1, relay_id2]}}}
               )

      refute Map.has_key?(result, :errors)

      assert Enum.sort(result.data["listBaseImages"]["results"]) ==
               Enum.sort([
                 %{"id" => relay_id1, "name" => "one"},
                 %{"id" => relay_id2, "name" => "two"}
               ])
    end

    test "read_one query filters by relay global id" do
      image =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "solo"})
        |> Ash.create!()

      relay_id = AshGraphql.Resource.encode_relay_id(image)

      assert {:ok, result} =
               """
               query ReadOneBaseImage($filter: BaseImageFilterInput!) {
                 readOneBaseImage(filter: $filter) {
                   id
                   name
                 }
               }
               """
               |> Absinthe.run(Schema, variables: %{"filter" => %{"id" => %{"eq" => relay_id}}})

      refute Map.has_key?(result, :errors)
      assert result.data["readOneBaseImage"] == %{"id" => relay_id, "name" => "solo"}
    end
  end

  describe "filter_handlers subscriptions" do
    test "subscription filter accepts relay global id" do
      image =
        BaseImage
        |> Ash.Changeset.for_create(:create, %{name: "subscribed"})
        |> Ash.create!()

      relay_id = AshGraphql.Resource.encode_relay_id(image)

      assert {:ok, %{"subscribed" => topic}} =
               """
               subscription BaseImageEvents($filter: BaseImageFilterInput) {
                 baseImageEvents(filter: $filter) {
                   updated {
                     id
                     name
                   }
                 }
               }
               """
               |> Absinthe.run(Schema,
                 variables: %{"filter" => %{"id" => %{"eq" => relay_id}}},
                 context: %{pubsub: PubSub}
               )

      image
      |> Ash.Changeset.for_update(:update, %{name: "updated"})
      |> Ash.update!()

      assert_receive {^topic, %{data: subscription_data}}

      assert subscription_data["baseImageEvents"]["updated"] == %{
               "id" => relay_id,
               "name" => "updated"
             }
    end
  end
end
