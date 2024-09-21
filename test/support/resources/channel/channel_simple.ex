defmodule AshGraphql.Test.ChannelSimple do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :channel_simple

    mutations do
      update :update_channel, :update_channel, read_action: :read_channel, identity: false
    end
  end

  actions do
    default_accept(:*)

    create(:create, primary?: true)

    read(:read, primary?: true)

    update(:update, primary?: true)

    destroy(:destroy, primary?: true)

    read :read_channel do
      argument(:channel_id, :uuid, allow_nil?: false)

      get?(true)

      prepare(fn query, _ ->
        channel_id = Ash.Query.get_argument(query, :channel_id)

        case AshGraphql.Test.Channel
             |> Ash.Query.for_read(:read, %{})
             |> Ash.Query.filter(id == ^channel_id)
             |> Ash.read_one() do
          {:ok, channel} ->
            query
            |> Ash.DataLayer.Simple.set_data([
              struct(AshGraphql.Test.ChannelSimple, %{
                channel: channel
              })
            ])

          {:error, error} ->
            query |> Ash.Query.add_error(error)
        end
      end)
    end

    update :update_channel do
      require_atomic?(false)

      argument(:name, :string, allow_nil?: false)

      change(fn changeset, _ ->
        name = Ash.Changeset.get_argument(changeset, :name)

        channel =
          changeset.data.channel
          |> Ash.Changeset.for_update(:update, name: name)
          |> Ash.update!()

        %{changeset | data: %{changeset.data | channel: channel}}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :channel, :struct do
      constraints(instance_of: AshGraphql.Test.Channel)
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:created_at, public?: true)
  end
end
