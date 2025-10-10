# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_grapqhl

  graphql do
  end

  resources do
    resource(AshGraphql.Test.RelaySubscribable)
  end
end
