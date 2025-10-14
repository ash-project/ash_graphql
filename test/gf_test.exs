# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.Test do
  use ExUnit.Case

  test "basic" do
    group =
      GF.Group
      |> Ash.Changeset.for_create(:create, %{abbreviation: "TG", name: "Test Group"})
      |> Ash.create!(authorize?: false)

    Ash.DataLayer.Simple.set_data(GF.Group, [group])

    event =
      GF.Event
      |> Ash.Changeset.for_create(:create, %{title: "Test Event"}, tenant: group.id)
      |> Ash.create!(authorize?: false)

    assert event.id

    Ash.DataLayer.Simple.set_data(GF.Event, [event])

    assert Ash.get!(GF.Event, event.id, authorize?: false)

    member =
      GF.Member
      |> Ash.Changeset.for_create(
        :create,
        %{email: "test@example.com", name: "Test Member", status: :active},
        tenant: group.id
      )
      |> Ash.create!(authorize?: false)

    actor =
      GF.Member
      |> Ash.Changeset.for_create(
        :create,
        %{email: "actor@example.com", name: "Actor Member", status: :inactive},
        tenant: group.id
      )
      |> Ash.create!(authorize?: false)

    Ash.DataLayer.Simple.set_data(GF.Member, [member, actor])

    attendee =
      GF.Attendee
      |> Ash.Changeset.for_create(:create, %{event_id: event.id, member_id: member.id})
      |> Ash.create!(authorize?: false)

    Ash.DataLayer.Simple.set_data(GF.Attendee, [attendee])

    assert attendee.id

    {:ok, %{data: data}} =
      """
      query GetEvent($id: ID!) {
        getEvent(id: $id) {
          id
          title
          attendees(filter: {member: {status: {eq: ACTIVE}}}) {
            id
            member {
              id
              name
            }
          }
        }
      }
      """
      |> Absinthe.run(GF.AshGraphqlSchema,
        variables: %{"id" => event.id},
        context: %{actor: actor}
      )

    assert data["getEvent"]
  end
end
