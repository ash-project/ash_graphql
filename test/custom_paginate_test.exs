defmodule AshGraphql.CustomPaginateTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "custom type pagination" do
    setup do
      :ok
    end

    test "channel record with direct union message records are fetched" do
      channel =
        AshGraphql.Test.Channel
        |> Ash.Changeset.for_create(:create, name: "test channel")
        |> Ash.create!()

      text_message =
        AshGraphql.Test.TextMessage
        |> Ash.Changeset.for_create(:create, text: "test text message")
        |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
        |> Ash.create!()

      image_message =
        AshGraphql.Test.ImageMessage
        |> Ash.Changeset.for_create(:create, text: "test image message")
        |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
        |> Ash.create!()

      resp =
        """
        query ChannelWithUnionMessages($id: ID!) {
          channel(id: $id) {
            id
            directChannelMessages {
              ...on TextMessage {
                __typename
                id
                text
                type
              }
              ...on ImageMessage {
                __typename
                id
                text
                type
              }
            }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"id" => channel.id})

      assert {:ok, result} = resp

      refute Map.has_key?(result, :errors)

      assert %{
        data:
          %{
            "channel" => %{
              "id" => channel.id,
              "directChannelMessages" => [
                %{
                  "__typename" => "TextMessage",
                  "id" => text_message.id,
                  "text" => text_message.text,
                  "type" => "TEXT"
                },
                %{
                  "__typename" => "ImageMessage",
                  "id" => image_message.id,
                  "text" => image_message.text,
                  "type" => "IMAGE"
                }
              ]
            }
          } ==
            result
      }
    end

    test "channel record with page of channel messages record is fetched" do
      channel =
        AshGraphql.Test.Channel
        |> Ash.Changeset.for_create(:create, name: "test channel")
        |> Ash.create!()

      text_message =
        AshGraphql.Test.TextMessage
        |> Ash.Changeset.for_create(:create, text: "test text message")
        |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
        |> Ash.create!()

      image_message =
        AshGraphql.Test.ImageMessage
        |> Ash.Changeset.for_create(:create, text: "test image message")
        |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
        |> Ash.create!()

      resp =
        """
        query ChannelWithCustomPageOfChannelMessages($id: ID!) {
          channel(id: $id) {
            id
            indirectChannelMessages {
              count
              hasNextPage
              results {
                ...on TextMessage {
                  __typename
                  id
                  text
                  type
                }
                ...on ImageMessage {
                  __typename
                  id
                  text
                  type
                }
              }
            }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"id" => channel.id})

      assert {:ok, result} = resp

      refute Map.has_key?(result, :errors)

      assert %{
        data:
          %{
            "channel" => %{
              "id" => channel.id,
              "indirectChannelMessages" => %{
                "count" => 2,
                "hasNextPage" => false,
                "results" => [
                  %{
                    "__typename" => "TextMessage",
                    "id" => text_message.id,
                    "text" => text_message.text,
                    "type" => "TEXT"
                  },
                  %{
                    "__typename" => "ImageMessage",
                    "id" => image_message.id,
                    "text" => image_message.text,
                    "type" => "IMAGE"
                  }
                ]
              }
            }
          } ==
            result
      }
    end
  end

  @tag skip: "See https://github.com/ash-project/ash_graphql/issues/239"
  test "loading relationships with filter by actor works" do
    user_1 =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!(authorize?: false)

    user_2 =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!(authorize?: false)

    channel =
      AshGraphql.Test.Channel
      |> Ash.Changeset.for_create(:create, name: "test channel")
      |> Ash.create!()

    text_message =
      AshGraphql.Test.TextMessage
      |> Ash.Changeset.for_create(:create, text: "test text message")
      |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
      |> Ash.create!()

    AshGraphql.Test.MessageViewableUser
    |> Ash.Changeset.for_create(:create, %{user_id: user_1.id, message_id: text_message.id})
    |> Ash.create!()

    image_message =
      AshGraphql.Test.ImageMessage
      |> Ash.Changeset.for_create(:create, text: "test image message")
      |> Ash.Changeset.manage_relationship(:channel, channel, type: :append_and_remove)
      |> Ash.create!()

    AshGraphql.Test.MessageViewableUser
    |> Ash.Changeset.for_create(:create, %{user_id: user_2.id, message_id: image_message.id})
    |> Ash.create!()

    resp =
      """
      query ChannelWithUnionFilterByActorChannelMessages($id: ID!) {
        channel(id: $id) {
          id
          filterByActorChannelMessages {
            count
            hasNextPage
            results {
              ...on TextMessage {
                __typename
                id
                text
                type
              }
              ...on ImageMessage {
                __typename
                id
                text
                type
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => channel.id},
        context: %{actor: user_1}
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    %{
      "channel" => %{
        "id" => _,
        "filterByActorChannelMessages" => %{
          "count" => count,
          "hasNextPage" => _,
          "results" => results
        }
      }
    } = result.data

    refute count != Enum.count(results)
  end
end
