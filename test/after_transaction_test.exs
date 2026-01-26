# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.AfterTransactionEts do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn -> AshGraphql.TestHelpers.stop_ets() end)
  end

  describe "create mutation" do
    test "after_transaction is called on success" do
      """
      mutation CreateAfterTransactionEts($input: CreateAfterTransactionEtsInput!) {
        createAfterTransactionEts(input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"name" => "test"}},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :create, {:ok, _}}
    end

    test "after_transaction is called on error" do
      """
      mutation CreateAfterTransactionEtsWithError($input: CreateAfterTransactionEtsWithErrorInput!) {
        createAfterTransactionEtsWithError(input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"name" => "test"}},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :create_with_error, {:error, _}}
    end
  end

  describe "update mutation" do
    test "after_transaction is called on success" do
      record =
        AshGraphql.Test.AfterTransactionEts
        |> Ash.Changeset.for_create(:create, %{name: "original"})
        |> Ash.create!()

      """
      mutation UpdateAfterTransactionEts($id: ID!, $input: UpdateAfterTransactionEtsInput!) {
        updateAfterTransactionEts(id: $id, input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id, "input" => %{"name" => "updated"}},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :update, {:ok, _}}
    end

    test "after_transaction is called on error" do
      record =
        AshGraphql.Test.AfterTransactionEts
        |> Ash.Changeset.for_create(:create, %{name: "original"})
        |> Ash.create!()

      """
      mutation UpdateAfterTransactionEtsWithError($id: ID!, $input: UpdateAfterTransactionEtsWithErrorInput!) {
        updateAfterTransactionEtsWithError(id: $id, input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id, "input" => %{"name" => "updated"}},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :update_with_error, {:error, _}}
    end
  end

  describe "destroy mutation" do
    test "after_transaction is called on success" do
      record =
        AshGraphql.Test.AfterTransactionEts
        |> Ash.Changeset.for_create(:create, %{name: "to_destroy"})
        |> Ash.create!()

      """
      mutation DestroyAfterTransactionEts($id: ID!) {
        destroyAfterTransactionEts(id: $id) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :destroy, {:ok, _}}
    end

    test "after_transaction is called on error" do
      record =
        AshGraphql.Test.AfterTransactionEts
        |> Ash.Changeset.for_create(:create, %{name: "to_destroy"})
        |> Ash.create!()

      """
      mutation DestroyAfterTransactionEtsWithError($id: ID!) {
        destroyAfterTransactionEtsWithError(id: $id) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id},
        context: %{context: %{test_pid: self()}}
      )

      assert_receive {:after_transaction, :destroy_with_error, {:error, _}}
    end
  end
end
