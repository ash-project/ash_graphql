defmodule AshGraphql.Test.DoubleRelEmbed do
  @moduledoc false

  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :double_rel_embed
  end

  attributes do
    attribute(:recursive?, :string, default: "No, not I, but me dad be!")
  end
end
