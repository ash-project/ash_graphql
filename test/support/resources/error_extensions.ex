# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ErrorExtensionsResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.ErrorExtensionsDomain,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  policies do
    policy action(:count) do
      authorize_if(actor_present())
    end
  end

  graphql do
    type :error_extensions_resource

    queries do
      action :error_extensions_count, :count
    end
  end

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    action :count, :integer do
      run(fn _input, _context -> {:ok, 0} end)
    end
  end
end
