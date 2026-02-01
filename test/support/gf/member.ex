# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.Member do
  @moduledoc false
  use Ash.Resource,
    domain: GF.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource],
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query
  require Logger

  alias GF.ActiveMemberPolicy
  alias GF.Group
  alias GF.Types.MemberStatus

  @roles_options [
    admin: "Admin Site",
    content: "Content Management",
    developer: "Developer",
    elections: "Elections",
    events: "Events",
    finances: "Finances",
    forum: "Forum Moderatrion",
    group_announcements: "Group Announcements",
    members: "Members Management",
    super: "Superuser"
  ]

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :string, public?: true)
    attribute(:group_id, :uuid, public?: false)

    attribute(:name, :string,
      default: "",
      allow_nil?: false,
      constraints: [allow_empty?: true],
      public?: true
    )

    attribute :roles, {:array, :string} do
      default([])
      public?(true)
    end

    attribute(:status, MemberStatus, public?: true)

    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:group, Group, public?: true)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :destroy, :update])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)

    global?(true)
  end

  policies do
    bypass {ActiveMemberPolicy, role: :members} do
      authorize_if(always())
    end

    policy action(:read) do
      authorize_if(expr(id == ^actor(:id)))
      authorize_if({ActiveMemberPolicy, []})
    end
  end

  @any_member_fields [
    :name,
    :status
  ]

  @member_self_fields @any_member_fields ++
                        [
                          :email,
                          :inserted_at,
                          :roles
                        ]

  #  Note: field_policies are only considered for _reading_ data.
  field_policies do
    field_policy_bypass @member_self_fields, actor_attribute_equals(:__struct__, __MODULE__) do
      authorize_if(expr(id == ^actor(:id)))
      forbid_if(always())
    end

    field_policy_bypass @member_self_fields do
      authorize_if(expr(id == ^actor(:id)))
    end

    field_policy @any_member_fields do
      authorize_if({ActiveMemberPolicy, []})
    end
  end

  graphql do
    type :gf_member
  end

  code_interface do
    define(:create, action: :create)
    define(:get_by_id, action: :read, get_by: :id, not_found_error?: false)
  end

  def can_take_role_action?(%{status: :active} = member, role) do
    has_any_role_access?(member, role)
  end

  def can_take_role_action?(_member_or_nil, _role) do
    false
  end

  def has_any_role_access?(member, roles) when is_list(roles) do
    Enum.any?(roles, &has_role_access?(member, &1))
  end

  def has_any_role_access?(member, role) when is_atom(role) do
    has_role_access?(member, role)
  end

  def has_role_access?(%{} = member, role) when is_atom(role) do
    active? = member.status == :active

    cond do
      @roles_options[role] == nil ->
        Logger.warning("Unrecognized role: #{inspect(role)}")
        false

      active? == false ->
        false

      to_string(role) in member.roles ->
        true

      role == :admin and Enum.any?(member.roles) ->
        true

      "super" in member.roles and role != :developer ->
        true

      true ->
        false
    end
  end

  def has_role_access?(_other, _role), do: false
end
