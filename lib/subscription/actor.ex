# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Subscription.Actor do
  @moduledoc """
  Allows the user to substitue an actor for another more generic actor, 
  this can be used to deduplicate subscription execution
  """

  # I'd like to have the typespec say that actor can be anything
  # but that the input and output must be the same
  @callback actor(actor :: any, opts :: Keyword.t()) :: actor :: any
end
