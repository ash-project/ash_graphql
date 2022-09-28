defmodule AshGraphql.TestHelpers do
  @moduledoc false
  require Logger

  def stop_ets do
    for resource <- Ash.Registry.Info.entries(AshGraphql.Test.Registry) do
      try do
        Ash.DataLayer.Ets.stop(resource)
      rescue
        error ->
          Logger.warn("Error while stopping storage for #{inspect(resource)}: #{inspect(error)}")
          :ok
      end
    end
  end
end
