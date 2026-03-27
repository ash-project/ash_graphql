# SPDX-FileCopyrightText: 2026 ash_graphql contributors
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.MultiSchema do
  @moduledoc """
  A second Absinthe schema that shares AshGraphql.Test.Domain with the
  primary AshGraphql.Test.Schema. Used to verify that the same domain
  can appear in multiple schemas without module conflicts.
  """

  defmodule SchemaB do
    @moduledoc false

    use Absinthe.Schema

    # Intentionally registers the same domain as AshGraphql.Test.Schema
    # Using OtherDomain which is also registered in the primary schema
    use AshGraphql, domains: [AshGraphql.Test.OtherDomain]

    query do
    end

    mutation do
    end
  end
end
