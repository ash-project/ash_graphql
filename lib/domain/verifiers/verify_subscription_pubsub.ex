# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Domain.Verifiers.VerifySubscriptionPubsub do
  @moduledoc """
  Verifies that pubsub is properly configured for subscriptions at the domain level.

  This verifier ensures that:
  - If a domain has subscriptions, it either has pubsub configured or all its resources with subscriptions have pubsub configured
  - Resources with subscriptions have pubsub available either at the resource level or domain level
  """

  use Spark.Dsl.Verifier

  def verify(dsl) do
    domain_subscriptions = AshGraphql.Domain.Info.subscriptions(dsl)
    domain_pubsub = AshGraphql.Domain.Info.subscription_pubsub(dsl)

    if is_nil(domain_pubsub) do
      already_checked =
        if domain_subscriptions != [] do
          domain_subscriptions
          |> Enum.map(fn subscription ->
            resource = subscription.resource

            Code.ensure_loaded!(resource)

            resource_pubsub = AshGraphql.Resource.Info.subscription_pubsub(resource)

            unless resource_pubsub do
              raise Spark.Error.DslError,
                module: Spark.Dsl.Transformer.get_persisted(resource.spark_dsl_config(), :module),
                message:
                  "Domain subscription for #{inspect(resource)} requires pubsub to be configured either at the domain level or on the resource #{inspect(resource)} itself.",
                path: [:graphql, :subscriptions, subscription.name]
            end

            resource
          end)
        else
          []
        end

      dsl
      |> Ash.Domain.Info.resources()
      |> Kernel.--(already_checked)
      |> Enum.each(fn resource ->
        Code.ensure_loaded!(resource)

        resource_subscriptions = AshGraphql.Resource.Info.subscriptions(resource, dsl)

        if resource_subscriptions != [] do
          resource_pubsub = AshGraphql.Resource.Info.subscription_pubsub(resource)

          unless resource_pubsub do
            raise Spark.Error.DslError,
              module: Spark.Dsl.Transformer.get_persisted(resource.spark_dsl_config(), :module),
              message:
                "Resource #{inspect(resource)} has subscriptions but no pubsub module configured. A pubsub module must be specified either at the resource level (in the subscriptions section) or at the domain level (in the domain's graphql subscriptions section).",
              path: [:graphql, :subscriptions, :pubsub]
          end
        end
      end)
    end

    :ok
  end
end
