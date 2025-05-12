defmodule AshGraphql.Test.SimpleDomain do
  @moduledoc false
  # Used for simple one-off manual tests

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end

    subscriptions do
    end
  end

  resources do
    resource(AshGraphql.Test.SimpleResource)
  end
end
