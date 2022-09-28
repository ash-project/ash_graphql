defmodule AshGraphql.TestHelpers do
  @moduledoc false
  def stop_ets() do
    for resource <- Ash.Registry.Info.entries(AshGraphql.Test.Registry) do
      try do
        Ash.DataLayer.Ets.stop(resource)
      rescue
        _ ->
          :ok
      end
    end
  end
end
