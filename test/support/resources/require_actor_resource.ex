# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RequireActorResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.RequireActorDomain,
    extensions: [AshGraphql.Resource],
    data_layer: Ash.DataLayer.Ets

  graphql do
    type :require_actor_resource
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    action :ping, :boolean do
      run(fn _input, _context ->
        {:ok, true}
      end)
    end
  end
end
