defmodule AshGraphql.Resource.Subscription.DefaultConfig do
  alias AshGraphql.Resource.Subscription

  def create_config(%Subscription{} = subscription, api, resource) do
    config_module = String.to_atom(Macro.camelize(Atom.to_string(subscription.name)) <> ".Config")
    dbg()

    defmodule config_module do
      require Ash.Query

      @subscription subscription
      @resource resource
      @api api
      def config(_args, %{context: context}) do
        read_action =
          @subscription.read_action || Ash.Resource.Info.primary_action!(@resource, :read).name

        case Ash.Api.can(
               @api,
               Ash.Query.for_read(@resource, read_action)
               |> Ash.Query.filter(id == "test"),
               context[:actor],
               run_queries?: false,
               alter_source?: true
             ) do
          {:ok, true} ->
            {:ok, topic: "*", context_id: "global"}

          {:ok, true, filter} ->
            {:ok, topic: "*", context_id: Base.encode64(:erlang.term_to_binary(filter))}

          _ ->
            {:error, "unauthorized"}
        end
      end
    end

    &config_module.config/2
  end
end
