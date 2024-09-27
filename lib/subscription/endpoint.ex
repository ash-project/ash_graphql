defmodule AshGraphql.Subscription.Endpoint do
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Phoenix.Endpoint

      defdelegate run_docset(pubsub, docs_and_topics, notification),
        to: AshGraphql.Subscription.Runner
    end
  end
end
