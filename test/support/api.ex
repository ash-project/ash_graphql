defmodule AshGraphql.Test.Api do
  @moduledoc false

  use Ash.Api

  resources do
    resource(AshGraphql.Test.Comment)
    resource(AshGraphql.Test.Post)
    resource(AshGraphql.Test.PostTag)
    resource(AshGraphql.Test.Tag)
    resource(AshGraphql.Test.User)
    resource(AshGraphql.Test.NonIdPrimaryKey)
    resource(AshGraphql.Test.CompositePrimaryKey)
  end
end
