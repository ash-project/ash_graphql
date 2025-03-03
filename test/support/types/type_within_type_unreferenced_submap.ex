defmodule AshGraphql.Test.TypeWithinTypeUnreferencedSubmap do
  @moduledoc """
  This type exists due to a previous bug that types were not traversed
  properly if used as subtypes and not exposed anywhere directly.
  """
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        some: [
          type: :string,
          allow_nil?: false
        ],
        stuff: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :type_within_type_unreferenced_submap

  @impl true
  def graphql_input_type(_), do: :type_within_type_unreferenced_submap_input
end
