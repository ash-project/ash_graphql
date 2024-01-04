defmodule AshGraphql.Resource.Subscription.ConfigFunction do
  use AshGraphql.Resource.Subscription.Config

  @impl true
  def config(changeset, [fun: {m, f, a}], context) do
    apply(m, f, [changeset, context | a])
  end

  @impl true
  def config(changeset, [fun: fun], context) do
    fun.(changeset, context)
  end
end
