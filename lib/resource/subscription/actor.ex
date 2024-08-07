defmodule AshGraphql.Resource.Subscription.Actor do
  # I'd like to have the typespsay that actor can be anything
  # but that the input and output must be the same
  @callback author(actor :: any) :: actor :: any
end
