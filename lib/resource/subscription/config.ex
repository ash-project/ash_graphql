defmodule AshGraphql.Resource.Subscription.Config do
  @callback config(args :: map(), info :: map()) :: {:ok, Keyword.t()} | {:error, Keyword.t()}

  defmacro __using__(_) do
    quote do
      @behaviour AshGraphql.Resource.Subscription.Config
    end
  end
end
