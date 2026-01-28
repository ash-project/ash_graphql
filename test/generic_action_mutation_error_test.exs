# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.GenericActionMutationErrorTest do
  use ExUnit.Case

  test "raises helpful error when real generic action is used in create mutation block" do
    # This should raise an error with our improved message
    assert_raise RuntimeError, fn ->
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResource,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    end

    # Verify the error message contains helpful details
    try do
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResource,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    rescue
      e in RuntimeError ->
        error_message = Exception.message(e)

        # Verify it mentions the generic action
        assert error_message =~ "Invalid GraphQL mutation"
        assert error_message =~ "random_action"
        assert error_message =~ "create"
        assert error_message =~ "has type `:action`"
        assert error_message =~ "require an Ash action with type `:create`"
        assert error_message =~ "Fix:"
        assert error_message =~ "graphql.actions"
        assert error_message =~ "GenericActionErrorTestResource"
    end
  end

  test "raises helpful error when real generic action is used in update mutation block" do
    assert_raise RuntimeError, fn ->
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResourceUpdate,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    end

    try do
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResourceUpdate,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    rescue
      e in RuntimeError ->
        error_message = Exception.message(e)
        assert error_message =~ "Invalid GraphQL mutation"
        assert error_message =~ "count_action"
        assert error_message =~ "update"
        assert error_message =~ "has type `:action`"
        assert error_message =~ "require an Ash action with type `:update`"
        assert error_message =~ "Fix:"
        assert error_message =~ "graphql.actions"
    end
  end

  test "raises helpful error when real generic action is used in destroy mutation block" do
    assert_raise RuntimeError, fn ->
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResourceDestroy,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    end

    try do
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionErrorTestResourceDestroy,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )
    rescue
      e in RuntimeError ->
        error_message = Exception.message(e)
        assert error_message =~ "Invalid GraphQL mutation"
        assert error_message =~ "random_action"
        assert error_message =~ "destroy"
        assert error_message =~ "has type `:action`"
        assert error_message =~ "require an Ash action with type `:destroy`"
        assert error_message =~ "Fix:"
        assert error_message =~ "graphql.actions"
    end
  end

  test "correct usage of generic actions in action blocks does not raise errors" do
    # This should NOT raise an error - correct usage
    # Note: Generic actions with error_location: :top_level return empty list (no result object type needed)
    result =
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionCorrectUsageResource,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )

    # Should return mutation types successfully without raising an error
    assert is_list(result)
    # Empty list is valid for generic actions with top_level error_location
  end

  test "typed actions (create/update/destroy) work correctly in their respective blocks" do
    # This should NOT raise an error - correct usage of typed actions
    result =
      AshGraphql.Resource.mutation_types(
        AshGraphql.Test.GenericActionTypedActionsResource,
        AshGraphql.Test.Domain,
        [],
        AshGraphql.Test.Schema
      )

    # Should return mutation types successfully
    assert is_list(result)
    assert length(result) > 0
  end
end
