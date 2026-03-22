# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyActionsPublic do
  # Ensures that all actions exposed via GraphQL are `public?`
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    module = Transformer.get_persisted(dsl, :module)
    domain = Ash.Resource.Info.domain(dsl)

    dsl
    |> AshGraphql.Resource.Info.queries(domain)
    |> Enum.each(fn query ->
      action = Ash.Resource.Info.action(dsl, query.action)

      verify_action_public!(module, action, [:graphql, :queries, query.name])
    end)

    dsl
    |> AshGraphql.Resource.Info.mutations(domain)
    |> Enum.each(fn mutation ->
      action = Ash.Resource.Info.action(dsl, mutation.action)

      verify_action_public!(module, action, [:graphql, :mutations, mutation.name])

      if mutation.read_action do
        read_action = Ash.Resource.Info.action(dsl, mutation.read_action)

        verify_action_public!(module, read_action, [:graphql, :mutations, mutation.name])
      end
    end)

    dsl
    |> AshGraphql.Resource.Info.subscriptions(domain)
    |> Enum.each(fn subscription ->
      if subscription.read_action do
        read_action = Ash.Resource.Info.action(dsl, subscription.read_action)

        verify_action_public!(
          module,
          read_action,
          [:graphql, :subscriptions, subscription.name]
        )
      end
    end)

    :ok
  end

  defp verify_action_public!(module, action, path) do
    if action && !Map.get(action, :public?, true) do
      raise Spark.Error.DslError,
        module: module,
        path: path,
        message: """
        Action #{inspect(action.name)} on #{inspect(module)} is not `public?`.

        Only `public?` actions can be exposed via AshGraphql.
        """
    end
  end
end
