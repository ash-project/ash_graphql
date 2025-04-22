defmodule Type.LazyInitTest.Example do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    lazy_init?: true,
    constraints: [
      fields: [
        condition: [
          type: :string
        ],
        field: [
          type: :string
        ],
        operator: [
          type: :string
        ],
        value: [
          type: :string
        ],
        predicates: [
          type: {:array, __MODULE__}
        ]
      ]
    ]

  def graphql_type(_), do: :predicate
  def graphql_input_type(_), do: :predicate_input
end
