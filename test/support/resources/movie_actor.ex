# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.MovieActor do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:create, :update, :destroy, :read])
  end

  relationships do
    belongs_to :movie, AshGraphql.Test.Movie do
      primary_key?(true)
      allow_nil?(false)
    end

    belongs_to :actor, AshGraphql.Test.Actor do
      primary_key?(true)
      allow_nil?(false)
    end
  end
end
