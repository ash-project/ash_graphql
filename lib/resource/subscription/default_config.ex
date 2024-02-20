defmodule AshGraphql.Resource.Subscription.DefaultConfig do
  def config(_, _), do: dbg({:ok, topic: "*"})
end
