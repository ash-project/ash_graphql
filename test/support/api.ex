defmodule AshGraphql.Test.Api do
  @moduledoc false

  use Ash.Api

  resources do
    resource(AshGraphql.Test.Post)
    resource(AshGraphql.Test.Comment)
  end
end
