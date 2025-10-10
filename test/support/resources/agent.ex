# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Agent do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:agent)

    paginate_relationship_with(actors: :relay)
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
  end

  relationships do
    many_to_many(:actors, AshGraphql.Test.Actor,
      through: AshGraphql.Test.ActorAgent,
      public?: true
    )
  end
end
