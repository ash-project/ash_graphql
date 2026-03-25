# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.GroupedQueriesResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type(:grouped_queries_item)

    queries do
      group :content do
        list(:gq_unique_items, :read)

        action(:gq_unique_stats, :stats) do
        end
      end
    end
  end

  actions do
    default_accept(:*)
    defaults([:read])

    action :stats, :integer do
      run(fn _input, _context ->
        {:ok, 0}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
  end
end
