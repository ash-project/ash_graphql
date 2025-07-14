defmodule AshGraphql.Resource.Verifiers.VerifySubscriptionActions do
  # Validates the paginate_relationship_with option
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    subscriptions = AshGraphql.Resource.Info.subscriptions(dsl, Ash.Resource.Info.domain(dsl))

    if subscriptions != [] do
      verify_pubsub(dsl, subscriptions)
    end

    subscriptions
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

  defp verify_pubsub(dsl, _subscriptions) do
    resource_pubsub = AshGraphql.Resource.Info.subscription_pubsub(dsl)

    domain_pubsub =
      case Ash.Resource.Info.domain(dsl) do
        nil ->
          nil

        domain ->
          Code.ensure_loaded!(domain)
          AshGraphql.Domain.Info.subscription_pubsub(domain)
      end

    unless resource_pubsub || domain_pubsub do
      raise Spark.Error.DslError,
        module: Transformer.get_persisted(dsl, :module),
        message:
          "A pubsub module must be specified either at the resource level (in the subscriptions section) or at the domain level (in the domain's graphql subscriptions section).",
        path: [:graphql, :subscriptions, :pubsub]
    end
  end
end
