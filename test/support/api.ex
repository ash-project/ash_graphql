defmodule AshGraphql.Test.Api do
  @moduledoc false

  use Ash.Api

  resources do
    resource(AshGraphql.Test.Comment)
    resource(AshGraphql.Test.Post)
    resource(AshGraphql.Test.User)
  end
end
