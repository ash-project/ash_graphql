defmodule AshGraphql.Test.NestedEmbed do
  @moduledoc false

  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :nested_embed
  end

  attributes do
    attribute(:name, :string)
    attribute(:enum, AshGraphql.Test.NestedEnum)
  end
end
