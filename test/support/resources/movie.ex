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
      get :get_movie, :read
      list :get_movies, :read, paginate_with: nil
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :read, :update, :destroy])
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
