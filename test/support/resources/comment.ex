# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Comment do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :comment

    queries do
      list :list_comments, :read
      action :list_ranked_comments, :ranked_comments
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

    create :with_required do
      argument(:text, :string, allow_nil?: false)
      argument(:required, :string, allow_nil?: false)
      change(set_attribute(:text, arg(:text)))
    end

    read :paginated do
      pagination(required?: true, offset?: true, countable: true)
    end

    action :ranked_comments, {:array, RankedComment} do
      run(fn _input, _ctx ->
        res =
          Ash.read!(__MODULE__)
          |> Enum.with_index()
          |> Enum.map(fn {c, i} ->
            %{
              rank: i,
              comment: c
            }
          end)

        {:ok, res}
      end)
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

    calculate :arg_returned,
              :integer,
              expr(^arg(:seconds)) do
      argument(:seconds, :integer, allow_nil?: false)
      public?(true)
    end
  end

  relationships do
    belongs_to(:post, AshGraphql.Test.Post, public?: true)

    belongs_to :author, AshGraphql.Test.User do
      public?(true)
      attribute_writable?(true)
    end
  end
end
