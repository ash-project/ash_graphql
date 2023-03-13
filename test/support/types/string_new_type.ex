defmodule AshGraphql.Types.StringNewType do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :string, constraints: [match: ~r/hello/]
end
