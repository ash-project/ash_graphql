defmodule AshGraphql.Resource.Verifiers.VerifySubscriptionOptIn do
  # Checks if the users has opted into using subscriptions
  @moduledoc false

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Transformer

  def verify(dsl) do
    has_subscriptions =
      not (dsl
           |> AshGraphql.Resource.Info.subscriptions()
           |> Enum.empty?())

    if has_subscriptions && not Application.get_env(:ash_graphql, :subscriptions, false) do
      raise Spark.Error.DslError,
        module: Transformer.get_persisted(dsl, :module),
        message: "Subscriptions are in beta and must be enabled in the config",
        path: [:graphql, :subscriptions]
    end

    :ok
  end
end
