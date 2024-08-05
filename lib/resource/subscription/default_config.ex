defmodule AshGraphql.Resource.Subscription.DefaultConfig do
  alias AshGraphql.Resource.Subscription

  def create_config(%Subscription{} = subscription, _domain, resource) do
    config_module = String.to_atom(Macro.camelize(Atom.to_string(subscription.name)) <> ".Config")

    defmodule config_module do
      require Ash.Query

      @subscription subscription
      @resource resource
      def config(_args, %{context: context}) do
        read_action =
          @subscription.read_action || Ash.Resource.Info.primary_action!(@resource, :read).name

        case Ash.can(
               Ash.Query.for_read(@resource, read_action),
               context[:actor],
               run_queries?: false,
               alter_source?: true
             ) do
          {:ok, true} ->
            {:ok, topic: "*", context_id: "global"}

          {:ok, true, filter} ->
            # context_id is exposed to the client so we might need to encrypt it
            # or save it in ets or something and send generate a hash or something
            # as the context_id
            dbg(filter)
            {:ok, topic: "*", context_id: dbg(Base.encode64(:erlang.term_to_binary(filter)))}

          e ->
            {:error, "unauthorized"}
        end
      end
    end

    &config_module.config/2
  end
end
