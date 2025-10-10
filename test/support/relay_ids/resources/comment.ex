# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.Comment do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.RelayIds.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :comment

    queries do
      list :list_comments, :read
    end

    mutations do
      create :create_comment, :create
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
      default(:comment)
      constraints(one_of: [:comment, :reply])
    end

    create_timestamp(:created_at)
  end

  calculations do
    calculate(
      :timestamp,
      :utc_datetime_usec,
      expr(created_at),
      public?: true
    )
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.RelayIds.Post, public?: true)

    belongs_to :author, AshGraphql.Test.RelayIds.User do
      public?(true)
      attribute_writable?(true)
    end
  end
end
