defmodule AshGraphql.Test.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry(AshGraphql.Test.Comment)
    entry(AshGraphql.Test.CompositePrimaryKey)
    entry(AshGraphql.Test.CompositePrimaryKeyNotEncoded)
    entry(AshGraphql.Test.DoubleRelRecursive)
    entry(AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed)
    entry(AshGraphql.Test.MapTypes)
    entry(AshGraphql.Test.MultitenantPostTag)
    entry(AshGraphql.Test.MultitenantTag)
    entry(AshGraphql.Test.NoObject)
    entry(AshGraphql.Test.NonIdPrimaryKey)
    entry(AshGraphql.Test.Post)
    entry(AshGraphql.Test.PostTag)
    entry(AshGraphql.Test.RelayPostTag)
    entry(AshGraphql.Test.RelayTag)
    entry(AshGraphql.Test.SponsoredComment)
    entry(AshGraphql.Test.Subscribable)
    entry(AshGraphql.Test.Tag)
    entry(AshGraphql.Test.User)
    entry(AshGraphql.Test.Channel)
    entry(AshGraphql.Test.Message)
    entry(AshGraphql.Test.TextMessage)
    entry(AshGraphql.Test.ImageMessage)
  end
end
