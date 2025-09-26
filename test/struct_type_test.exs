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

      result =
        AshGraphql.Resource.field_type(
          mock_attribute.type,
          mock_attribute,
          mock_resource,
          # output type
          false
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

      result =
        AshGraphql.Resource.field_type(
          mock_attribute.type,
          mock_attribute,
          mock_resource,
          # input type
          true
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

      user_result =
        AshGraphql.Resource.field_type(
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

      post_result =
        AshGraphql.Resource.field_type(
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
        # Not a resource
        constraints: [instance_of: String],
        name: :invalid_struct
      }

      result =
        AshGraphql.Resource.field_type(
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
        # No instance_of
        constraints: [],
        name: :plain_struct
      }

      result =
        AshGraphql.Resource.field_type(
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

      result =
        AshGraphql.Resource.field_type(
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

      result =
        AshGraphql.Resource.field_type(
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

      result =
        AshGraphql.Resource.struct_input_type_definition(
          resource,
          AshGraphql.Test.Domain,
          [AshGraphql.Test.Domain],
          schema
        )

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

      result =
        AshGraphql.Resource.struct_input_type_definition(
          resource,
          AshGraphql.Test.Domain,
          [AshGraphql.Test.Domain],
          schema
        )

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
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end
      end

      result =
        AshGraphql.Resource.struct_input_type_definition(
          TestResourceWithoutGraphql,
          AshGraphql.Test.Domain,
          [AshGraphql.Test.Domain],
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
          uuid_primary_key(:id, public?: false)
          # No public attributes
        end
      end

      result =
        AshGraphql.Resource.struct_input_type_definition(
          TestResourceNoPublicAttrs,
          AshGraphql.Test.Domain,
          [AshGraphql.Test.Domain],
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

      # All fields should be for shown attributes and relationships only
      field_names = Enum.map(fields, & &1.identifier)

      # Get all public attributes and relationships
      public_attrs = Ash.Resource.Info.public_attributes(resource)
      public_rels = Ash.Resource.Info.public_relationships(resource)

      # Check that all generated fields correspond to either public attributes or relationships
      Enum.each(field_names, fn field_name ->
        # Check if it's a valid attribute
        # Check if it's a valid relationship
        is_valid_field =
          Enum.any?(public_attrs, fn attr ->
            attr.name == field_name &&
              AshGraphql.Resource.Info.show_field?(resource, attr.name)
          end) ||
            Enum.any?(public_rels, fn rel ->
              rel.name == field_name &&
                AshGraphql.Resource.Info.show_field?(resource, rel.name) &&
                AshGraphql.Resource in Spark.extensions(rel.destination) &&
                AshGraphql.Resource.Info.type(rel.destination)
            end)

        assert is_valid_field,
               "Field #{field_name} is not a valid shown attribute or relationship"
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

      type_defs =
        AshGraphql.Resource.type_definitions(
          resource,
          AshGraphql.Test.Domain,
          all_domains,
          schema,
          false
        )

      # Find the struct input type definition
      struct_input_def =
        Enum.find(type_defs, fn def ->
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

      type_defs =
        AshGraphql.Resource.type_definitions(
          resource,
          AshGraphql.Test.Domain,
          all_domains,
          schema,
          false
        )

      # Count struct input type definitions
      struct_input_count =
        Enum.count(type_defs, fn def ->
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

  describe "collision detection" do
    test "skips input type generation when it would conflict with existing resource" do
      # Create a resource that would normally generate a struct input type
      defmodule TestResourceBase do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_resource_base
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end
      end

      # Create another resource with the exact type name that would be generated as input
      defmodule TestResourceBaseInput do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          # This conflicts with what would be auto-generated
          type :test_resource_base_input
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:data, :string, public?: true)
        end
      end

      # Create a domain that includes both resources
      defmodule TestDomainWithConflict do
        use Ash.Domain, validate_config_inclusion?: false

        resources do
          resource(TestResourceBase)
          resource(TestResourceBaseInput)
        end
      end

      schema = AshGraphql.Test.Schema

      # Test that struct input type generation is skipped for TestResourceBase
      # because TestResourceBaseInput already uses the :test_resource_base_input type
      result =
        AshGraphql.Resource.struct_input_type_definition(
          TestResourceBase,
          TestDomainWithConflict,
          [TestDomainWithConflict],
          schema
        )

      # Should return nil due to collision detection
      assert result == nil
    end

    test "generates input type when no collision exists" do
      # Create a resource that can safely generate a struct input type
      defmodule TestResourceNonConflicting do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_resource_non_conflicting
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end
      end

      defmodule TestDomainNoConflict do
        use Ash.Domain, validate_config_inclusion?: false

        resources do
          resource(TestResourceNonConflicting)
        end
      end

      schema = AshGraphql.Test.Schema

      # Test that struct input type generation works when no conflicts exist
      result =
        AshGraphql.Resource.struct_input_type_definition(
          TestResourceNonConflicting,
          TestDomainNoConflict,
          [TestDomainNoConflict],
          schema
        )

      # Should generate the input type successfully
      assert %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{} = result
      assert result.identifier == :test_resource_non_conflicting_input
      assert result.name == "TestResourceNonConflictingInput"
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed constraints gracefully" do
      mock_attribute = %{
        type: Ash.Type.Struct,
        # nil instance_of
        constraints: [instance_of: nil],
        name: :malformed_struct
      }

      # Should not crash
      result =
        AshGraphql.Resource.field_type(
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
      result =
        AshGraphql.Resource.field_type(
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

      result =
        AshGraphql.Resource.field_type(
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
      result =
        AshGraphql.Resource.struct_input_fields(
          # Resource with no shown fields
          AshGraphql.Test.NoObject,
          AshGraphql.Test.Schema
        )

      # Should return empty list or handle gracefully
      assert is_list(result)
    end
  end

  describe "relationship handling in struct input types" do
    test "includes belongs_to relationships in struct input fields" do
      # Test that belongs_to relationships are included in struct input generation
      # Has belongs_to :author relationship
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)
      field_names = Enum.map(fields, & &1.identifier)

      # Should include the author relationship if it's public and shown
      relationships = Ash.Resource.Info.public_relationships(resource)
      author_rel = Enum.find(relationships, &(&1.name == :author))

      if author_rel && AshGraphql.Resource.Info.show_field?(resource, :author) do
        assert :author in field_names

        # Find the author field and check its type
        author_field = Enum.find(fields, &(&1.identifier == :author))
        assert author_field != nil
        # Should be the input type for User resource
        assert author_field.type == :user_input
      end
    end

    test "includes has_many relationships in struct input fields" do
      # Test that has_many relationships are included
      # Has has_many :comments relationship
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)
      field_names = Enum.map(fields, & &1.identifier)

      # Check if comments relationship exists and is public
      relationships = Ash.Resource.Info.public_relationships(resource)
      comments_rel = Enum.find(relationships, &(&1.name == :comments))

      if comments_rel && AshGraphql.Resource.Info.show_field?(resource, :comments) do
        assert :comments in field_names

        # Find the comments field and check its type
        comments_field = Enum.find(fields, &(&1.identifier == :comments))
        assert comments_field != nil
        # Should be a list of comment input types
        assert %Absinthe.Blueprint.TypeReference.List{of_type: :comment_input} =
                 comments_field.type
      end
    end

    test "handles resources with multiple relationship types" do
      # Create a test resource with both belongs_to and has_many relationships
      defmodule TestResourceWithRelationships do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_with_rels
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
          attribute(:user_id, :uuid, public?: true)
        end

        relationships do
          belongs_to :user, AshGraphql.Test.User do
            public?(true)
            attribute_writable?(true)
          end

          has_many :posts, AshGraphql.Test.Post do
            public?(true)
            destination_attribute(:author_id)
            source_attribute(:user_id)
          end
        end
      end

      schema = AshGraphql.Test.Schema
      fields = AshGraphql.Resource.struct_input_fields(TestResourceWithRelationships, schema)
      field_names = Enum.map(fields, & &1.identifier)

      # Should include both attribute and relationships
      assert :name in field_names
      assert :user_id in field_names
      assert :user in field_names
      assert :posts in field_names

      # Check field types
      user_field = Enum.find(fields, &(&1.identifier == :user))
      posts_field = Enum.find(fields, &(&1.identifier == :posts))

      assert user_field.type == :user_input
      assert %Absinthe.Blueprint.TypeReference.List{of_type: :post_input} = posts_field.type
    end

    test "filters out relationships to non-GraphQL resources" do
      # Create a resource with a relationship to a non-GraphQL resource
      defmodule TestNonGraphqlTarget do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets

        # No GraphQL extension - should be filtered out

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end
      end

      defmodule TestResourceWithNonGraphqlRel do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_non_graphql_rel
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end

        relationships do
          belongs_to :non_graphql_target, TestNonGraphqlTarget do
            public?(true)
          end
        end
      end

      schema = AshGraphql.Test.Schema
      fields = AshGraphql.Resource.struct_input_fields(TestResourceWithNonGraphqlRel, schema)
      field_names = Enum.map(fields, & &1.identifier)

      # Should include the attribute but not the non-GraphQL relationship
      assert :name in field_names
      refute :non_graphql_target in field_names
    end

    test "respects show_field? settings for relationships" do
      # Create a resource with a hidden relationship
      defmodule TestResourceWithHiddenRel do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_hidden_rel
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end

        relationships do
          belongs_to :user, AshGraphql.Test.User do
            # Hidden relationship
            public?(false)
          end
        end
      end

      schema = AshGraphql.Test.Schema
      fields = AshGraphql.Resource.struct_input_fields(TestResourceWithHiddenRel, schema)
      field_names = Enum.map(fields, & &1.identifier)

      # Should include the attribute but not the hidden relationship
      assert :name in field_names
      refute :user in field_names
    end

    test "handles circular relationship references safely" do
      # Test with resources that reference each other
      # This tests that we don't get infinite recursion
      # May have relationships back to other resources
      resource = AshGraphql.Test.User
      schema = AshGraphql.Test.Schema

      # This should not crash or cause infinite recursion
      fields = AshGraphql.Resource.struct_input_fields(resource, schema)

      # Should return a valid list of fields
      assert is_list(fields)

      # All fields should be valid field definitions
      Enum.each(fields, fn field ->
        assert %Absinthe.Blueprint.Schema.FieldDefinition{} = field
        assert is_atom(field.identifier)
        assert is_binary(field.name)
      end)
    end

    test "handles relationship cardinality correctly" do
      # Test that :one relationships generate single input types
      # and :many relationships generate list input types
      resource = AshGraphql.Test.Post
      schema = AshGraphql.Test.Schema

      fields = AshGraphql.Resource.struct_input_fields(resource, schema)

      # Check each relationship field has correct cardinality handling
      relationships = Ash.Resource.Info.public_relationships(resource)

      Enum.each(relationships, fn rel ->
        if AshGraphql.Resource.Info.show_field?(resource, rel.name) &&
             AshGraphql.Resource.Info.type(rel.destination) do
          field = Enum.find(fields, &(&1.identifier == rel.name))

          if field do
            case rel.cardinality do
              :one ->
                # Should be a single input type
                expected_type =
                  String.to_atom("#{AshGraphql.Resource.Info.type(rel.destination)}_input")

                assert field.type == expected_type

              :many ->
                # Should be a list of input types
                expected_input_type =
                  String.to_atom("#{AshGraphql.Resource.Info.type(rel.destination)}_input")

                assert %Absinthe.Blueprint.TypeReference.List{of_type: ^expected_input_type} =
                         field.type
            end
          end
        end
      end)
    end
  end

  describe "integration with real resources" do
    test "DeliveryException resource generates proper struct input type" do
      # This tests the actual use case that motivated this feature
      # DeliveryException should generate input types with relationships included

      # Mock the DeliveryException-like resource for testing
      defmodule TestDeliveryException do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :delivery_exception
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:reason, :string, public?: true)
          attribute(:company_id, :uuid, public?: true)
          attribute(:parcel_id, :uuid, public?: true)
        end

        relationships do
          # Using User as a mock Company
          belongs_to :company, AshGraphql.Test.User do
            public?(true)
            attribute_writable?(true)
          end

          # Using Post as a mock Parcel
          belongs_to :parcel, AshGraphql.Test.Post do
            public?(true)
            attribute_writable?(true)
          end

          # Using Comment as mock
          has_many :delivery_attribute_values, AshGraphql.Test.Comment do
            public?(true)
            destination_attribute(:post_id)
            source_attribute(:parcel_id)
          end
        end
      end

      schema = AshGraphql.Test.Schema

      # Test struct input type definition generation
      result =
        AshGraphql.Resource.struct_input_type_definition(
          TestDeliveryException,
          AshGraphql.Test.Domain,
          [AshGraphql.Test.Domain],
          schema
        )

      assert %Absinthe.Blueprint.Schema.InputObjectTypeDefinition{} = result
      assert result.identifier == :delivery_exception_input
      assert result.name == "DeliveryExceptionInput"

      # Test that fields include both attributes and relationships
      fields = result.fields
      field_names = Enum.map(fields, & &1.identifier)

      # Should include attributes
      assert :reason in field_names
      assert :company_id in field_names
      assert :parcel_id in field_names

      # Should include relationships
      assert :company in field_names
      assert :parcel in field_names
      assert :delivery_attribute_values in field_names

      # Check relationship field types
      company_field = Enum.find(fields, &(&1.identifier == :company))
      parcel_field = Enum.find(fields, &(&1.identifier == :parcel))

      delivery_attr_values_field =
        Enum.find(fields, &(&1.identifier == :delivery_attribute_values))

      # belongs_to -> single input type
      assert company_field.type == :user_input
      # belongs_to -> single input type
      assert parcel_field.type == :post_input
      # has_many -> list input type
      assert %Absinthe.Blueprint.TypeReference.List{of_type: :comment_input} =
               delivery_attr_values_field.type
    end

    test "struct input types work with Ash.Type.Struct field type generation" do
      # Test that the field_type function works correctly with our new struct input types
      defmodule TestResourceWithStructField do
        use Ash.Resource,
          domain: nil,
          extensions: [AshGraphql.Resource],
          data_layer: Ash.DataLayer.Ets

        graphql do
          type :test_struct_field
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string, public?: true)
        end
      end

      # Test generating field type for struct with instance_of pointing to our test resource
      mock_attribute = %{
        type: Ash.Type.Struct,
        constraints: [instance_of: TestResourceWithStructField],
        name: :test_struct,
        allow_nil?: false
      }

      # Test input type generation
      input_result =
        AshGraphql.Resource.field_type(
          mock_attribute.type,
          mock_attribute,
          AshGraphql.Test.User,
          # input? = true
          true
        )

      assert input_result == :test_struct_field_input

      # Test output type generation
      output_result =
        AshGraphql.Resource.field_type(
          mock_attribute.type,
          mock_attribute,
          AshGraphql.Test.User,
          # input? = false
          false
        )

      assert output_result == :test_struct_field
    end
  end

  describe "backward compatibility" do
    test "does not break existing Map type behavior" do
      mock_attribute = %{
        type: Ash.Type.Map,
        constraints: [],
        name: :map_field
      }

      result =
        AshGraphql.Resource.field_type(
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

      result =
        AshGraphql.Resource.field_type(
          mock_attribute.type,
          mock_attribute,
          AshGraphql.Test.User,
          true
        )

      # Should fall back to Map behavior as before
      assert result == :json_string || result == :json
    end
  end

  describe "collision detection for input types" do
    test "prevents collision when existing resource conflicts with generated struct input type" do
      # This reproduces the PlanJob/PlanJobInput issue where an embedded resource
      # exists with the same name as what would be generated for struct input types

      # Create a regular resource that would try to generate a struct input type
      defmodule TestPlanJob do
        use Ash.Resource,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshGraphql.Resource]

        graphql do
          type :plan_job
        end

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:create, :read, :update, :destroy]
        end
      end

      # Create an embedded resource that already uses the would-be generated input type name
      # This simulates PlanJobInput - it's embedded, has AshGraphql extension, but isn't in domain
      defmodule TestPlanJobInput do
        use Ash.Resource,
          data_layer: :embedded,
          extensions: [AshGraphql.Resource]

        graphql do
          type :plan_job_input  # This conflicts with what TestPlanJob would generate
        end

        attributes do
          uuid_primary_key :id
          attribute :data, :string, public?: true
        end

        actions do
          defaults [:create]
        end
      end

      # Domain only includes the main resource, not the embedded one
      defmodule TestCollisionDomain do
        use Ash.Domain

        resources do
          resource TestPlanJob
          # Note: TestPlanJobInput is NOT included here, just like in Zelo
        end
      end

      # Create a schema that includes the embedded resource, simulating how
      # embedded resources still generate types in the schema
      defmodule TestCollisionSchema do
        use Absinthe.Schema

        # Include the domain resources
        use AshGraphql, domains: [TestCollisionDomain]

        # Add a basic query root to satisfy Absinthe schema requirements
        query do
          field :test, :string
        end

        # Manually add the embedded resource type to simulate how it appears in real schemas
        input_object :plan_job_input do
          field :data, :string
        end
      end

      # The collision detection should prevent duplicate PlanJobInput generation
      # This test verifies that the schema compiles without type name conflicts

      # Both types should exist without conflicts - if collision detection worked,
      # the schema should compile successfully
      plan_job_type = Absinthe.Schema.lookup_type(TestCollisionSchema, :plan_job)
      plan_job_input_type = Absinthe.Schema.lookup_type(TestCollisionSchema, :plan_job_input)

      assert plan_job_type != nil
      assert plan_job_input_type != nil
      assert plan_job_type.identifier == :plan_job
      assert plan_job_input_type.identifier == :plan_job_input
    end
  end
end
