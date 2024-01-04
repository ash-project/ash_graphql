defmodule AshGraphql.Resource.Subscription.ResolveFunction do
  use AshGraphql.Resource.Subscription.Resolve

  @impl true
  def resolve(changeset, [fun: {m, f, a}], context) do
    apply(m, f, [changeset, context | a])
  end

  @impl true
  def resolve(changeset, [fun: fun], context) do
    fun.(changeset, context)
  end
end
