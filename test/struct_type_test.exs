defmodule AshGraphql.StructTypeTest do
  use ExUnit.Case, async: false

  describe "Ash.Type.Struct field type generation" do
    test "generates correct output type for struct with instance_of" do
      mock_resource = AshGraphql.Test.User
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: AshGraphql.Test.Post],
        name: :post_struct,
        allow_nil?: false
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        mock_resource,
        false  # output type
      )

      assert result == :post
    end

    test "generates correct input type for struct with instance_of" do
      mock_resource = AshGraphql.Test.User
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: AshGraphql.Test.Post],
        name: :post_struct,
        allow_nil?: false
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        mock_resource,
        true  # input type
      )

      assert result == :post_input
    end

    test "handles struct types with different resource constraints" do
      # Test with User resource
      user_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: AshGraphql.Test.User],
        name: :user_struct
      }

      user_result = AshGraphql.Resource.field_type(
        user_attribute.type,
        user_attribute,
        AshGraphql.Test.Post,
        true
      )

      assert user_result == :user_input

      # Test with different resource
      post_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: AshGraphql.Test.Post],
        name: :post_struct
      }

      post_result = AshGraphql.Resource.field_type(
        post_attribute.type,
        post_attribute,
        AshGraphql.Test.User,
        true
      )

      assert post_result == :post_input
    end

    test "falls back to Map behavior when instance_of is not a resource" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: String],  # Not a resource
        name: :invalid_struct
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should fall back to Map behavior (json_string)
      assert result == :json_string || result == :json
    end

    test "falls back to Map behavior when no instance_of constraint" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [],  # No instance_of
        name: :plain_struct
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should fall back to Map behavior
      assert result == :json_string || result == :json
    end

    test "handles nil constraints gracefully" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: nil,
        name: :nil_constraints_struct
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should fall back to Map behavior
      assert result == :json_string || result == :json
    end

    test "handles array of struct types" do
      mock_attribute = %{
        type: {:array, Ash.Type.Struct},
        constraints: [items: [instance_of: AshGraphql.Test.Post]],
        name: :post_array
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should handle array types appropriately
      assert result != nil
    end
  end

  describe "struct input type definition generation" do
    test "generates input type definition for valid resource" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      result = AshGraphql.Resource.struct_input_type_definition(resource, schema)

      assert %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{} = result
      assert result.identifier == :post_input
      assert result.name == "PostInput"
      assert result.module == schema
      assert is_list(result.fields)
      assert length(result.fields) > 0
    end

    test "generates input type definition for User resource" do
      resource = AshGraphql.Test.User
      schema = AshGraphql.Test.Schema

      result = AshGraphql.Resource.struct_input_type_definition(resource, schema)

      assert %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{} = result
      assert result.identifier == :user_input
      assert result.name == "UserInput"
    end

    test "returns nil for resource without GraphQL type" do
      # Create a mock resource module without GraphQL configuration
      defmodule TestResourceWithoutGraphql do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end
      end

      result = AshGraphql.Resource.struct_input_type_definition(
        TestResourceWithoutGraphql,
        AshGraphql.Test.Schema
      )

      assert result == nil
    end

    test "handles resource with no public attributes" do
      # Create a resource with no public attributes
      defmodule TestResourceNoPublicAttrs do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_no_attrs
        end

        attributes do
          uuid_primary_key :id, public?: false
          # No public attributes
        end
      end

      result = AshGraphql.Resource.struct_input_type_definition(
        TestResourceNoPublicAttrs,
        AshGraphql.Test.Schema
      )

      # Should return nil when no public fields are generated
      # The primary key :id is private, so no fields should be generated
      assert result == nil
    end
  end

  describe "struct input fields generation" do
    test "generates fields from resource public attributes" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)

      assert is_list(fields)
      assert length(fields) > 0

      # Check that all fields are proper field definitions
      Enum.each(fields, fn field ->
        assert %Absinthe.Blueprint.Schema.FieldDefinition{} = field
        assert is_atom(field.identifier)
        assert is_binary(field.name)
        assert field.module == schema
        assert field.type != nil
      end)
    end

    test "only includes shown fields" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)

      # All fields should be for shown attributes only
      field_names = Enum.map(fields, & &1.identifier)

      # Get all public attributes
      public_attrs = Ash.Resource.Info.public_attributes(resource)

      # Check that all generated fields correspond to public attributes
      Enum.each(field_names, fn field_name ->
        assert Enum.any?(public_attrs, fn attr ->
          attr.name == field_name &&
          AshGraphql.Resource.Info.show_field?(resource, attr.name)
        end)
      end)
    end

    test "uses field names mapping when configured" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)
      field_names_config = AshGraphql.Resource.Info.field_names(resource)

      # Check that field names are properly mapped
      Enum.each(fields, fn field ->
        expected_name =
          case field_names_config[field.identifier] do
            nil -> to_string(field.identifier)
            mapped_name -> to_string(mapped_name)
          end

        assert field.name == expected_name
      end)
    end

    test "handles different attribute types correctly" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)

      # Should have fields for different types
      field_types = Enum.map(fields, & &1.type)
      assert length(field_types) > 0

      # All field types should be valid (not nil)
      Enum.each(field_types, fn field_type ->
        assert field_type != nil
      end)
    end
  end

  describe "integration with type_definitions" do
    test "struct input types are included in resource type definitions" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema
      all_domains = [AshGraphql.Test.Domain]

      type_defs = AshGraphql.Resource.type_definitions(
        resource,
        AshGraphql.Test.Domain,
        all_domains,
        schema,
        false
      )

      # Find the struct input type definition
      struct_input_def = Enum.find(type_defs, fn def ->
        case def do
          %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{identifier: :post_input} ->
            true
          _ ->
            false
        end
      end)

      assert struct_input_def != nil
      assert struct_input_def.identifier == :post_input
      assert struct_input_def.name == "PostInput"
    end

    test "struct input types are not duplicated in type definitions" do
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema
      all_domains = [AshGraphql.Test.Domain]

      type_defs = AshGraphql.Resource.type_definitions(
        resource,
        AshGraphql.Test.Domain,
        all_domains,
        schema,
        false
      )

      # Count struct input type definitions
      struct_input_count = Enum.count(type_defs, fn def ->
        case def do
          %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{identifier: :post_input} ->
            true
          _ ->
            false
        end
      end)

      # Should only have one struct input type definition
      assert struct_input_count <= 1
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed constraints gracefully" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: nil],  # nil instance_of
        name: :malformed_struct
      }

      # Should not crash
      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      assert result == :json_string || result == :json
    end

    test "handles non-existent resource in instance_of" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: NonExistentResource],
        name: :non_existent_struct
      }

      # Should handle gracefully without crashing
      # Non-existent resources should fall back to JSON behavior
      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      assert result == :json_string || result == :json
    end

    test "validates that instance_of points to actual Ash resource" do
      # Test with a regular module that's not an Ash resource
      defmodule NotAnAshResource do
        def some_function, do: :ok
      end

      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: NotAnAshResource],
        name: :not_resource_struct
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should fall back to JSON since it's not a valid Ash resource
      assert result == :json_string || result == :json
    end

    test "handles empty field list gracefully" do
      # This tests the nil return when no fields are generated
      result = AshGraphql.Resource.struct_input_fields(
        AshGraphql.Test.NoObject,  # Resource with no shown fields
        AshGraphql.Test.Schema
      )

      # Should return empty list or handle gracefully
      assert is_list(result)
    end
  end

  describe "backward compatibility" do
    test "does not break existing Map type behavior" do
      mock_attribute = %{
        type: Ash.Type.Map,
        constraints: [],
        name: :map_field
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Map types should still work as before
      assert result == :json_string || result == :json
    end

    test "does not affect other struct type scenarios" do
      # Test struct type without instance_of constraint
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [fields: [name: [type: :string]]],
        name: :struct_with_fields
      }

      result = AshGraphql.Resource.field_type(
        mock_attribute.type,
        mock_attribute,
        AshGraphql.Test.User,
        true
      )

      # Should fall back to Map behavior as before
      assert result == :json_string || result == :json
    end
  end
end