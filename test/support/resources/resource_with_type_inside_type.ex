# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResourceWithTypeInsideType do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:resource_with_type_inside)

    queries do
    end

    mutations do
      action :create_type_inside_type, :custom_action
      action :retrieve_type_inside_type, :custom_action_two
    end
  end

  actions do
    default_accept(:*)

    action :custom_action, :boolean do
      argument(:type_with_type, AshGraphql.Test.TypeWithTypeInside, allow_nil?: false)

      run(fn _inputs, _ctx ->
        {:ok, true}
      end)
    end

    action :custom_action_two, AshGraphql.Test.CategoryHierarchy do
      run(fn _inputs, _ctx ->
        {:ok, %{categories: [%{name: "bananas"}]}}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:foo, :string, public?: true)
  end
end
