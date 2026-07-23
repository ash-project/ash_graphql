# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.TypedStructGenericActionTest do
  # Regression test for https://github.com/ash-project/ash_graphql/issues/458
  # A resource with no graphql type of its own (`generate_object? false`) that
  # exposes a generic action returning an `Ash.TypedStruct` must still generate
  # the struct's GraphQL object.
  use ExUnit.Case, async: true

  defmodule Thing do
    @moduledoc false
    @behaviour AshGraphql.Type

    use Ash.TypedStruct

    typed_struct do
      field(:ok, :boolean, allow_nil?: false)
      field(:note, :string)
    end

    @impl AshGraphql.Type
    def graphql_type(_constraints), do: :generic_action_typed_struct_thing

    @impl AshGraphql.Type
    def graphql_input_type(_constraints), do: :generic_action_typed_struct_thing_input
  end

  defmodule Checker do
    @moduledoc false
    use Ash.Resource,
      domain: AshGraphql.TypedStructGenericActionTest.Domain,
      extensions: [AshGraphql.Resource]

    graphql do
      generate_object?(false)
    end

    resource do
      require_primary_key?(false)
    end

    actions do
      action :check, Thing do
        run(fn _input, _ctx -> {:ok, %Thing{ok: true, note: "hi"}} end)
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, otp_app: :ash_graphql, extensions: [AshGraphql.Domain]

    graphql do
      queries do
        action(Checker, :check, :check)
      end
    end

    resources do
      resource(Checker)
    end
  end

  defmodule Schema do
    @moduledoc false
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.TypedStructGenericActionTest.Domain]

    query do
    end
  end

  test "the typed struct return type is registered" do
    assert %Absinthe.Type.Object{} =
             Absinthe.Schema.lookup_type(Schema, :generic_action_typed_struct_thing)
  end

  test "the generic action query can be run" do
    resp =
      """
      query {
        check {
          ok
          note
        }
      }
      """
      |> Absinthe.run(Schema)

    assert {:ok, %{data: %{"check" => %{"ok" => true, "note" => "hi"}}}} = resp
  end
end
