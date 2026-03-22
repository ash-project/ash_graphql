# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Domain.Verifiers.VerifyActionsPublic do
  # Ensures that all actions exposed via domain-level GraphQL config are `public?`
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    module = Transformer.get_persisted(dsl, :module)

    dsl
    |> AshGraphql.Domain.Info.queries()
    |> Enum.each(fn query ->
      action = Ash.Resource.Info.action(query.resource, query.action)

      verify_action_public!(module, query.resource, action, [:graphql, :queries, query.name])
    end)

    dsl
    |> AshGraphql.Domain.Info.mutations()
    |> Enum.each(fn mutation ->
      action = Ash.Resource.Info.action(mutation.resource, mutation.action)

      verify_action_public!(
        module,
        mutation.resource,
        action,
        [:graphql, :mutations, mutation.name]
      )

      if read_action = Map.get(mutation, :read_action) do
        read_action_info = Ash.Resource.Info.action(mutation.resource, read_action)

        verify_action_public!(
          module,
          mutation.resource,
          read_action_info,
          [:graphql, :mutations, mutation.name]
        )
      end
    end)

    dsl
    |> AshGraphql.Domain.Info.subscriptions()
    |> Enum.each(fn subscription ->
      if subscription.read_action do
        read_action = Ash.Resource.Info.action(subscription.resource, subscription.read_action)

        verify_action_public!(
          module,
          subscription.resource,
          read_action,
          [:graphql, :subscriptions, subscription.name]
        )
      end
    end)

    :ok
  end

  defp verify_action_public!(module, resource, action, path) do
    if action && !Map.get(action, :public?, true) do
      raise Spark.Error.DslError,
        module: module,
        path: path,
        message: """
        Action #{inspect(action.name)} on #{inspect(resource)} is not `public?`.

        Only `public?` actions can be exposed via AshGraphql.
        """
    end
  end
end
