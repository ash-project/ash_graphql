defmodule AshGraphql.Test.Embed do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :embed
  end

  attributes do
    attribute(:nested_embed, AshGraphql.Test.NestedEmbed, public?: true)
  end
end
