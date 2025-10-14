# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.NestedEmbed do
  @moduledoc false

  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :nested_embed
  end

  attributes do
    attribute(:name, :string, public?: true)
    attribute(:enum, AshGraphql.Test.NestedEnum, public?: true)
  end
end
