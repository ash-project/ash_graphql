# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ErrorHandling do
  @moduledoc "Example resource with error handling module."

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :error_handling

    mutations do
      create :create_error_handling, :create
      update :update_error_handling, :update
    end

    error_handler {ErrorHandler, :handle_error, []}
  end

  actions do
    default_accept(:*)
    defaults([:read, :destroy, :create])

    update :update do
      accept([:name])

      validate(fn _changeset, _context ->
        {:error, "error no matter what"}
      end)

      require_atomic?(false)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:name, [:name], pre_check_with: AshGraphql.Test.Domain)
  end
end

defmodule ErrorHandler do
  @moduledoc false
  def handle_error(error, context) do
    %{action: action} = context

    case action do
      :update -> %{error | message: "replaced! update"}
      _ -> %{error | message: "replaced!"}
    end
  end
end
