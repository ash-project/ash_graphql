# SPDX-FileCopyrightText: 2026 ash_graphql contributors
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.LabelsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  defmodule PublicSchema do
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.Test.Domain], labels: [:public]
    import_types(AshGraphql.Test.SchemaTypes)

    query do
    end

    mutation do
    end
  end

  defmodule AdminSchema do
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.Test.Domain], labels: [:admin]
    import_types(AshGraphql.Test.SchemaTypes)

    query do
    end

    mutation do
    end
  end

  defmodule LegacySchema do
    use Absinthe.Schema
    use AshGraphql, domains: [AshGraphql.Test.Domain]
    import_types(AshGraphql.Test.SchemaTypes)

    query do
    end

    mutation do
    end
  end

  test "a labelled schema only exposes queries with matching labels" do
    assert root_fields(PublicSchema, :query) == ["content", "getTag"]
    assert group_fields(PublicSchema, "ContentQueryGroup") == ["gqUniqueItems"]

    assert root_fields(AdminSchema, :query) == ["content", "getTags", "postCount"]
    assert group_fields(AdminSchema, "ContentQueryGroup") == ["gqUniqueStats"]
  end

  test "a labelled schema only exposes mutations and generated mutation types with matching labels" do
    assert root_fields(PublicSchema, :mutation) == [
             "createTag",
             "createTypeInsideType",
             "retrieveTypeInsideType",
             "simpleCreatePost"
           ]

    assert root_fields(AdminSchema, :mutation) == ["destroyTag", "updatePost"]

    public_types = type_names(PublicSchema)
    admin_types = type_names(AdminSchema)

    assert "SimpleCreatePostInput" in public_types
    refute "UpdatePostInput" in public_types
    assert "Foo" in public_types
    assert "FooInput" in public_types
    assert "Status" in public_types
    assert "CategoryHierarchy" in public_types
    assert "Category" in public_types
    assert "TypeWithTypeInsideInput" in public_types
    assert "TypeWithinTypeUnreferencedSubmapInput" in public_types

    assert "UpdatePostInput" in admin_types
    refute "SimpleCreatePostInput" in admin_types
    refute "CategoryHierarchy" in admin_types
    refute "Category" in admin_types
    refute "TypeWithTypeInsideInput" in admin_types
    refute "TypeWithinTypeUnreferencedSubmapInput" in admin_types
  end

  test "labelled schemas warn when manually defined Absinthe types are not imported" do
    warning =
      capture_io(:stderr, fn ->
        assert_raise Absinthe.Schema.Error, fn ->
          defmodule MissingImportedSchemaTypesSchema do
            use Absinthe.Schema
            use AshGraphql, domains: [AshGraphql.Test.Domain], labels: [:public]

            query do
            end

            mutation do
            end
          end
        end
      end)

    assert warning =~ "reference GraphQL types not defined or imported"
    assert warning =~ ":foo"
    assert warning =~ ":foo_input"
    assert warning =~ ":status"
    refute warning =~ ":category"
    refute warning =~ ":category_hierarchy"
    refute warning =~ ":type_with_type_inside_input"
    refute warning =~ ":type_within_type_unreferenced_submap_input"
  end

  test "schemas without labels preserve existing behavior" do
    assert "getTag" in root_fields(LegacySchema, :query)
    assert "getTags" in root_fields(LegacySchema, :query)
    assert "getPost" in root_fields(LegacySchema, :query)
    assert "postCount" in root_fields(LegacySchema, :query)

    assert "createTag" in root_fields(LegacySchema, :mutation)
    assert "destroyTag" in root_fields(LegacySchema, :mutation)
    assert "simpleCreatePost" in root_fields(LegacySchema, :mutation)
    assert "updatePost" in root_fields(LegacySchema, :mutation)

    assert group_fields(LegacySchema, "ContentQueryGroup") == [
             "gqUniqueItems",
             "gqUniqueStats"
           ]
  end

  test "schema labels must match at least one query or mutation" do
    assert_raise ArgumentError, ~r/:missing/, fn ->
      defmodule MissingLabelSchema do
        use Absinthe.Schema
        use AshGraphql, domains: [AshGraphql.Test.Domain], labels: [:missing]

        query do
        end
      end
    end
  end

  test "schema labels cannot be empty" do
    assert_raise ArgumentError, ~r/at least one label/, fn ->
      defmodule EmptyLabelsSchema do
        use Absinthe.Schema
        use AshGraphql, domains: [AshGraphql.Test.Domain], labels: []

        query do
        end
      end
    end
  end

  defp root_fields(schema, type) do
    query = """
    {
      __schema {
        queryType {
          fields {
            name
          }
        }
        mutationType {
          fields {
            name
          }
        }
      }
    }
    """

    assert {:ok, %{data: %{"__schema" => data}}} = Absinthe.run(query, schema)

    data
    |> Map.fetch!("#{type}Type")
    |> Map.fetch!("fields")
    |> Enum.map(& &1["name"])
    |> Enum.sort()
  end

  defp group_fields(schema, group_type) do
    query = """
    {
      __type(name: "#{group_type}") {
        fields {
          name
        }
      }
    }
    """

    assert {:ok, %{data: %{"__type" => %{"fields" => fields}}}} = Absinthe.run(query, schema)

    fields
    |> Enum.map(& &1["name"])
    |> Enum.sort()
  end

  defp type_names(schema) do
    query = """
    {
      __schema {
        types {
          name
        }
      }
    }
    """

    assert {:ok, %{data: %{"__schema" => %{"types" => types}}}} = Absinthe.run(query, schema)

    Enum.map(types, & &1["name"])
  end
end
