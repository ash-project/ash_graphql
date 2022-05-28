defmodule AshGraphql.Test.Api do
  @moduledoc false

  use Ash.Api,
    extensions: [
      AshGraphql.Api
    ],
    otp_app: :ash_graphql

  resources do
    registry(AshGraphql.Test.Registry)
  end
end
