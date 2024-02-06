defmodule AshGraphql.Resource.Transformers.Subscription do
  @moduledoc """
  Adds the notifier for Subscriptions to the Resource
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    case dsl
         |> Transformer.get_entities([:graphql, :subscriptions]) do
      [] ->
        {:ok, dsl}

      _ ->
        {:ok,
         dsl
         |> Transformer.set_option(
           [:resource],
           :simple_notifiers,
           [
             AshGraphq.Resource.Subscription.Notifier
           ] ++
             Transformer.get_option(dsl, [:resource], :simple_notifiers, [])
         )
         |> dbg()}
    end

    {:ok, dsl}
  end
end
