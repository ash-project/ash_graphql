# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.SimpleResource do
  @moduledoc false
  # Used for simple one-off manual tests
  use Ash.Resource,
    extensions: [AshGraphql.Resource],
    domain: AshGraphql.Test.SimpleDomain

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end
