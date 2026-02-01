# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifySubscriptionActions do
  # Validates the paginate_relationship_with option
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    dsl
    |> AshGraphql.Resource.Info.subscriptions(Ash.Resource.Info.domain(dsl))
    |> Enum.each(&verify_actions(dsl, &1))

    :ok
  end

  defp verify_actions(dsl, subscription) do
    unless MapSet.subset?(
             MapSet.new(List.wrap(subscription.action_types)),
             MapSet.new([:create, :update, :destroy])
           ) do
      raise Spark.Error.DslError,
        module: Transformer.get_persisted(dsl, :module),
        message: "`action_types` values must be on of `[:create, :update, :destroy]`.",
        path: [:graphql, :subscriptions, subscription.name, :action_types]
    end

    missing_write_actions =
      MapSet.difference(
        MapSet.new(List.wrap(subscription.actions)),
        MapSet.new(
          Ash.Resource.Info.actions(dsl)
          |> Stream.filter(&(&1.type in [:create, :update, :destroy]))
          |> Enum.map(& &1.name)
        )
      )

    unless Enum.empty?(missing_write_actions) do
      raise Spark.Error.DslError,
        module: Transformer.get_persisted(dsl, :module),
        message:
          "The actions #{Enum.join(missing_write_actions, ", ")} do not exist on the resource.",
        path: [:graphql, :subscriptions, subscription.name, :actions]
    end

    unless is_nil(subscription.read_action) or
             subscription.read_action in (Ash.Resource.Info.actions(dsl)
                                          |> Stream.filter(&(&1.type == :read))
                                          |> Enum.map(& &1.name)) do
      raise Spark.Error.DslError,
        module: Transformer.get_persisted(dsl, :module),
        message: "The read action #{subscription.read_action} does not exist on the resource.",
        path: [:graphql, :subscriptions, subscription.name, :read_action]
    end
  end
end
