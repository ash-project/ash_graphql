# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.TestHelpers do
  @moduledoc false
  require Logger

  def stop_ets do
    for resource <- Ash.Domain.Info.resources(AshGraphql.Test.Domain) do
      try do
        Ash.DataLayer.Ets.stop(resource)
      rescue
        error ->
          Logger.warning(
            "Error while stopping storage for #{inspect(resource)}: #{inspect(error)}"
          )

          :ok
      end
    end
  end
end
