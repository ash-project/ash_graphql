defmodule AshGraphql.Test.RootLevelErrorsApi do
  @moduledoc false

  use Ash.Api,
    extensions: [
      AshGraphql.Api
    ],
    otp_app: :ash_graphql

  graphql do
    root_level_errors? true
  end

  resources do
    registry(AshGraphql.Test.Registry)
  end
end
