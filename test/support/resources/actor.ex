# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Actor do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:actor)

    paginate_relationship_with(agents: :relay)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
    attribute(:role, :atom, public?: true)
  end

  relationships do
    many_to_many(:movies, AshGraphql.Test.Movie,
      through: AshGraphql.Test.MovieActor,
      public?: true
    )

    many_to_many(:agents, AshGraphql.Test.Agent,
      through: AshGraphql.Test.ActorAgent,
      public?: true
    )
  end
end
