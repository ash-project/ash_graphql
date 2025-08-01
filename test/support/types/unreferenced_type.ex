defmodule AshGraphql.Test.UnreferencedType do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        some: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]
end
