defmodule AshGraphql.Resource.Subscription.Actor do
  # I'd like to have the typesp say that actor can be anything
  # but that the input and output must be the same
  @callback actor(actor :: any, opts :: Keyword.t()) :: actor :: any
end
