# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.OtherResource do
  @moduledoc false

  alias AshGraphql.Test.CommonMap
  alias AshGraphql.Test.CommonMapStruct

  use Ash.Resource,
    domain: AshGraphql.Test.OtherDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :other_resource

    queries do
      get :get_other_resource, :read
      list :list_other_resources, :read
    end

    mutations do
      create :create_other_resource_with_common_map, :create_with_common_map
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    create :create_with_common_map do
      argument(:common_map_arg, {:array, CommonMap})
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :common_map_attribute, CommonMap do
      public?(true)
    end

    attribute :common_map_struct_attribute, CommonMapStruct do
      public?(true)
    end
  end

  calculations do
    calculate :common_map_calculation, CommonMap do
      public?(true)
      calculation(fn records, _ -> {:ok, []} end)
    end
  end
end
