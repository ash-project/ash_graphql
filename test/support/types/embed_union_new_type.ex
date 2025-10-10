# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.EmbedUnionNewType do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        foo: [
          type: Foo,
          tag: :type,
          tag_value: :foo
        ],
        bar: [
          type: Bar,
          tag: :type,
          tag_value: :bar
        ]
      ]
    ]

  def graphql_type(_), do: :embed_union_new_type
end
