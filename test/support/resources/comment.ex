defmodule AshGraphql.Test.Comment do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :comment

    queries do
      get :get_comment, :read
      list :list_comments, :read
    end

    mutations do
      create :create_comment, :create
    end
  end

  actions do
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
    attribute(:text, :string)

    attribute :type, :atom do
      writable?(false)
      default(:comment)
      constraints(one_of: [:comment, :reply])
    end

    create_timestamp(:created_at)
  end

  calculations do
    calculate(
      :timestamp,
      :utc_datetime_usec,
      expr(created_at)
    )
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.Post)

    belongs_to :author, AshGraphql.Test.User do
      attribute_writable?(true)
    end
  end
end
