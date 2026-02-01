# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResourceWithTypedStruct do
  @moduledoc false

  alias AshGraphql.Test.PersonTypedStructData

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :resource_with_typed_struct

    queries do
      get :get_typed_struct_resource, :read
      list :list_typed_struct_resources, :read
    end

    mutations do
      create :create_typed_struct_resource, :create
      update :update_typed_struct_resource, :update
      destroy :destroy_typed_struct_resource, :destroy
      action(:create_from_typed_struct, :create_from_typed_struct)
      action(:get_as_typed_struct, :get_as_typed_struct)
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])

    action :create_from_typed_struct, :uuid do
      argument(:person_data, PersonTypedStructData, allow_nil?: false)

      run(fn input, _context ->
        case Ash.Changeset.get_argument(input, :person_data) do
          %PersonTypedStructData{name: name, age: age, email: email} ->
            __MODULE__
            |> Ash.Changeset.new()
            |> Ash.Changeset.change_attribute(:name, name)
            |> Ash.Changeset.change_attribute(:age, age)
            |> Ash.Changeset.change_attribute(:email, email)
            |> Ash.Changeset.for_create(:create)
            |> Ash.create()
            |> case do
              {:ok, %{id: id}} -> {:ok, id}
              _ -> {:ok, -1}
            end

          _ ->
            {:ok, -1}
        end
      end)
    end

    action :get_as_typed_struct, PersonTypedStructData do
      argument(:id, :uuid, allow_nil?: false)

      run(fn %{arguments: %{id: id}}, _context ->
        case Ash.get(AshGraphql.Test.ResourceWithTypedStruct, id) do
          {:ok, %{name: name, age: age, email: email}} ->
            {:ok, %PersonTypedStructData{name: name, age: age, email: email}}

          {:error, _} = error ->
            error

          nil ->
            {:error, "Resource not found"}
        end
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:age, :integer, public?: true)
    attribute(:email, :string, public?: true)
    attribute(:created_at, :utc_datetime_usec, public?: true, default: &DateTime.utc_now/0)
  end
end
