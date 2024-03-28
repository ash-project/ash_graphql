defmodule AshGraphql.Test.SponsoredComment do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :sponsored_comment

    queries do
      get :get_sponsored_comment, :read
    end

    mutations do
      create :create_sponsored_comment, :create
    end
  end

  actions do
    default_accept(:*)
    defaults([:create, :update, :destroy])

    read :read do
      primary?(true)
    end

    read :paginated do
      pagination(required?: true, offset?: true, countable: true)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string, public?: true)

    attribute :type, :atom do
      public?(true)
      writable?(false)
      default(:sponsored)
    end
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.Post, public?: true)
  end
end
