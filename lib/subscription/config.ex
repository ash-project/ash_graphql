# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Subscription.Config do
  @moduledoc """
  Creates a config function used for the absinthe subscription definition

  See https://github.com/absinthe-graphql/absinthe/blob/3d0823bd71c2ebb94357a5588c723e053de8c66a/lib/absinthe/schema/notation.ex#L58
  """
  alias AshGraphql.Resource.Subscription

  # sobelow_skip ["DOS.StringToAtom"]
  def create_config(%Subscription{} = subscription, _domain, resource) do
    config_module = String.to_atom(Macro.camelize(Atom.to_string(subscription.name)) <> ".Config")

    Module.create(
      config_module,
      quote generated: true,
            bind_quoted: [subscription: Macro.escape(subscription), resource: resource] do
        require Ash.Query
        alias AshGraphql.Graphql.Resolver

        @subscription subscription
        @resource resource
        def config(args, %{context: context}) do
          read_action =
            @subscription.read_action || Ash.Resource.Info.primary_action!(@resource, :read).name

          actor =
            case @subscription.actor do
              {module, opts} ->
                module.actor(context[:actor], opts)

              _ ->
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
                   Resolver.massage_filter(@resource, Map.get(args, :filter))
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
      end,
      Macro.Env.location(__ENV__)
    )

    &config_module.config/2
  end
end
