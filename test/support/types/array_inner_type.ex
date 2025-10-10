# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Category do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        name: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]

  def graphql_type(_), do: :category
end

defmodule AshGraphql.Test.CategoryHierarchy do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        categories: [
          type: {:array, AshGraphql.Test.Category},
          allow_nil?: false,
          constraints: [
            nil_items?: false
          ]
        ]
      ]
    ]

  def graphql_type(_), do: :category_hierarchy
end
