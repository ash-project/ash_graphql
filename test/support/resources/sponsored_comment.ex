# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.SponsoredComment do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :sponsored_comment
    complexity {__MODULE__, :query_complexity}

    queries do
      get :get_sponsored_comment, :read, complexity: {__MODULE__, :query_complexity}
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

  @doc "Sponsored comments are complex to serve, add 100 to the cost per comment"
  def query_complexity(%{limit: n}, child_complexity, _resolution) do
    n * (child_complexity + 100)
  end

  def query_complexity(_args, child_complexity, _resolution) do
    child_complexity + 100
  end
end
