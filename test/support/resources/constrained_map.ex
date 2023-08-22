defmodule AshGraphql.Test.ConstrainedMap do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        foo_bar: [
          type: :string,
          constraints: [
            allow_nil?: false
          ]
        ],
        baz: [
          type: :integer
        ],
        bam: [
          type: :map,
          constraints: [
            fields: [
              qux: [
                type: :string
              ]
            ]
          ]
        ]
      ]
    ]

  def graphql_type, do: :constrained_map
  def graphql_input_type, do: :constrained_map_input
end
