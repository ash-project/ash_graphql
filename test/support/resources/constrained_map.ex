defmodule AshGraphql.Test.ConstrainedMap do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        foo: [
          type: :string,
          allow_nil?: false
        ],
        bar: [
          type: :integer
        ]
      ]
    ]

  def graphql_type, do: :constrained_map
end
