# SPDX-FileCopyrightText: 2026 ash_graphql contributors
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MultiSchemaTest do
  @moduledoc """
  Tests that the same domain can be registered in multiple Absinthe schemas
  without module conflicts or missing builtin types.
  """
  use ExUnit.Case, async: false

  # Two schemas sharing AshGraphql.Test.Domain — this should compile
  # without "cannot define module" errors or missing type errors.

  test "same domain in multiple schemas compiles without conflict" do
    # If we got here, both schemas compiled successfully.
    # AshGraphql.Test.Schema and AshGraphql.Test.MultiSchema.SchemaB
    # both include AshGraphql.Test.Domain.
    assert Code.ensure_loaded?(AshGraphql.Test.Schema)
    assert Code.ensure_loaded?(AshGraphql.Test.MultiSchema.SchemaB)
  end

  test "each schema has its own AshTypes module" do
    # Schema A's AshTypes (OtherDomain is in the primary schema's domain list)
    schema_a_types = Module.concat([AshGraphql.Test.Schema, AshGraphql.Test.OtherDomain, AshTypes])
    assert Code.ensure_loaded?(schema_a_types)

    # Schema B's AshTypes
    schema_b_types = Module.concat([AshGraphql.Test.MultiSchema.SchemaB, AshGraphql.Test.OtherDomain, AshTypes])
    assert Code.ensure_loaded?(schema_b_types)

    # They should be different modules
    assert schema_a_types != schema_b_types
  end

  test "SchemaB can execute a basic query" do
    # SchemaB should have builtin types (mutation_error, sort_order, page_info)
    # and be able to execute queries against shared domain resources
    assert {:ok, %{data: %{"__typename" => "RootQueryType"}}} =
             Absinthe.run("{ __typename }", AshGraphql.Test.MultiSchema.SchemaB)
  end
end
