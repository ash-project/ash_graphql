# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.CompositePrimaryKey do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :composite_primary_key
    primary_key_delimiter "~"

    queries do
      get :get_composite_primary_key, :read
    end
  end

  actions do
    defaults([:create, :update, :destroy, :read])
  end

  attributes do
    uuid_primary_key(:first)
    uuid_primary_key(:second)
  end
end
