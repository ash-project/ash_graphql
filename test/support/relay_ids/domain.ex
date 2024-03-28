defmodule AshGraphql.Test.RelayIds.Domain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  resources do
    resource(AshGraphql.Test.RelayIds.Post)
    resource(AshGraphql.Test.RelayIds.ResourceWithNoPrimaryKeyGet)
    resource(AshGraphql.Test.RelayIds.User)
  end
end
