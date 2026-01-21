# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RequireActorDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  authorization do
    require_actor?(true)
  end

  graphql do
    queries do
      action AshGraphql.Test.RequireActorResource, :require_actor_ping, :ping
    end
  end

  resources do
    resource(AshGraphql.Test.RequireActorResource)
  end
end
