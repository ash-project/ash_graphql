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
