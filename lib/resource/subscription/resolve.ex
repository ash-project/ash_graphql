defmodule AshGraphql.Resource.Subscription.Resolve do
  @callback resolve(args :: map(), info :: map(), resolution :: map()) ::
              {:ok, list()} | {:error, binary()}

  defmacro __using__(_) do
    quote do
      @behaviour AshGraphql.Resource.Subscription.Resolve
    end
  end
end
