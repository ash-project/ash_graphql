# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Movie do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:movie)

    paginate_relationship_with(actors: :relay, reviews: :offset, awards: :keyset)

    queries do
      get :get_movie, :read do
        meta meta_string: "bar", meta_integer: 1
      end

      list :get_movies, :read, paginate_with: nil
    end

    mutations do
      create :create_movie, :create_with_actors

      update :update_movie, :update do
        meta meta_string: "bar", meta_integer: 1
      end

      destroy :destroy_movie, :destroy
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])

    create :create_with_actors do
      argument :actor_ids, {:array, :uuid} do
        allow_nil? false
        constraints(min_length: 1)
      end

      change(manage_relationship(:actor_ids, :actors, type: :append))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string, public?: true)
  end

  relationships do
    many_to_many(:actors, AshGraphql.Test.Actor,
      through: AshGraphql.Test.MovieActor,
      public?: true
    )

    has_many(:reviews, AshGraphql.Test.Review, public?: true)
    has_many(:awards, AshGraphql.Test.Award, public?: true)
  end
end
