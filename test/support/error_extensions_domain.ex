# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ErrorExtensionsDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [AshGraphql.Domain],
    otp_app: :ash_graphql

  graphql do
    error_extensions?(true)
  end

  resources do
    resource(AshGraphql.Test.ErrorExtensionsResource)
  end
end
