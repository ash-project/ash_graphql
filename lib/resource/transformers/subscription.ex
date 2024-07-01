defmodule AshGraphql.Resource.Transformers.Subscription do
  @moduledoc """
  Adds the notifier for Subscriptions to the Resource
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    case dsl |> Transformer.get_entities([:graphql, :subscriptions]) do
      [] ->
        {:ok, dsl}

      _ ->
        {:ok,
         dsl
         |> Transformer.persist(
           :simple_notifiers,
           [
             AshGraphql.Resource.Subscription.Notifier
           ] ++
             Transformer.get_persisted(dsl, :simple_notifiers, [])
         )}
    end
  end
end
