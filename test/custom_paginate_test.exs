defmodule AshGraphql.CustpmPaginateTest do
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
        |> Ash.Changeset.for_create(:create, %{})
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
        |> Ash.Changeset.for_create(:create, %{})
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
end
