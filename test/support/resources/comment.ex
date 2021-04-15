defmodule AshGraphql.Test.Comment do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :comment

    queries do
      get :get_comment, :read
    end

    mutations do
      create :create_comment, :create
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string)
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.Post)
  end
end
