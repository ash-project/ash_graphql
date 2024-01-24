defmodule AshGraphql.Test.RelayIds.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry(AshGraphql.Test.RelayIds.Post)
    entry(AshGraphql.Test.RelayIds.ResourceWithNoPrimaryKeyGet)
    entry(AshGraphql.Test.RelayIds.User)
  end
end
