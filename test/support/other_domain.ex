# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.OtherDomain do
  @moduledoc false

  # This domain and its resource serves the purpose of testing deduplication of
  # common map types

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  resources do
    resource(AshGraphql.Test.OtherResource)
  end
end
