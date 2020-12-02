defmodule AshGraphql.Test.Api do
  use Ash.Api

  resources do
    resource(AshGraphql.Test.Post)
  end
end
