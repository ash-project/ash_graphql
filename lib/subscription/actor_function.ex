# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Subscription.ActorFunction do
  @moduledoc false

  @behaviour AshGraphql.Subscription.Actor

  @impl true
  def actor(actor, [{:fun, {m, f, a}}]) do
    apply(m, f, [actor | a])
  end

  @impl true
  def actor(actor, [{:fun, fun}]) do
    fun.(actor)
  end
end
