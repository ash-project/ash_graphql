defmodule AshGraphql.Test.RelayIds.Api do
  @moduledoc false

  use Ash.Api,
    extensions: [
      AshGraphql.Api
    ],
    otp_app: :ash_graphql

  resources do
    registry(AshGraphql.Test.RelayIds.Registry)
  end
end
