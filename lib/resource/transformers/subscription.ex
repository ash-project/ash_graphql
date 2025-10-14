# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
             AshGraphql.Subscription.Notifier
           ] ++
             Transformer.get_persisted(dsl, :simple_notifiers, [])
         )}
    end
  end
end
