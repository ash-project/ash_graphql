defmodule AshGraphql.Subscription.Config do
  alias AshGraphql.Resource.Subscription

  def create_config(%Subscription{} = subscription, _domain, resource) do
    config_module = String.to_atom(Macro.camelize(Atom.to_string(subscription.name)) <> ".Config")

    defmodule config_module do
      require Ash.Query

      @subscription subscription
      @resource resource
      def config(args, %{context: context}) do
        read_action =
          @subscription.read_action || Ash.Resource.Info.primary_action!(@resource, :read).name

        actor =
          if is_function(@subscription.actor) do
            # might be nice to also pass in the subscription, that way you could potentially
            # deduplicate on an action basis as well if you wanted to
            @subscription.actor.(context[:actor])
          else
            context[:actor]
          end

        # check with Ash.can? to make sure the user is able to read the resource
        # otherwise we return an error here instead of just never sending something
        # in the subscription
        case Ash.can(
               @resource
               |> Ash.Query.new()
               # not sure if we need this here
               |> Ash.Query.do_filter(
                 AshGraphql.Graphql.Resolver.massage_filter(@resource, Map.get(args, :filter))
               )
               |> Ash.Query.set_tenant(context[:tenant])
               |> Ash.Query.for_read(read_action),
               actor,
               tenant: context[:tenant],
               run_queries?: false,
               alter_source?: true
             ) do
          {:ok, true} ->
            {:ok, topic: "*", context_id: create_context_id(args, actor, context[:tenant])}

          {:ok, true, _} ->
            {:ok, topic: "*", context_id: create_context_id(args, actor, context[:tenant])}

          _ ->
            {:error, "unauthorized"}
        end
      end

      def create_context_id(args, actor, tenant) do
        Base.encode64(:crypto.hash(:sha256, :erlang.term_to_binary({args, actor, tenant})))
      end
    end

    &config_module.config/2
  end
end
