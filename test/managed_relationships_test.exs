# defmodule AshGraphql.ManagedRelationshipsTest do
#   use ExUnit.Case, async: false

#   setup do
#     on_exit(fn ->
#       try do
#         ETS.Set.delete(ETS.Set.wrap_existing!(AshGraphql.Test.Post))
#         ETS.Set.delete(ETS.Set.wrap_existing!(AshGraphql.Test.Comment))
#       rescue
#         _ ->
#           :ok
#       end
#     end)
#   end
# end
