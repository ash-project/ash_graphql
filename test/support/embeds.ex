defmodule Foo do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: :embedded,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :foo_embed
  end

  attributes do
    attribute :type, :atom do
      public?(true)
      constraints(one_of: [:foo])
      writable?(false)
    end

    attribute :foo, :string do
      public?(true)
      allow_nil? false
    end
  end

  calculations do
    calculate(:always_true, :boolean, expr(true), public?: true)
    calculate(:always_nil, :boolean, expr(nil), public?: true)
  end
end

defmodule Bar do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: :embedded,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :bar_embed
  end

  attributes do
    attribute :type, :atom do
      public?(true)
      constraints(one_of: [:foo])
      writable?(false)
    end

    attribute :bar, :string do
      public?(true)
      allow_nil? false
    end
  end

  calculations do
    calculate(:always_true, :boolean, expr(true), public?: true)
    calculate(:always_false, :boolean, expr(false), public?: true)
  end
end
