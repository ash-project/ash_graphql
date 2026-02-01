# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.AfterTransactionMnesiaTest do
  @moduledoc "Tests after_transaction with Mnesia (real transactions)"
  use ExUnit.Case, async: false

  setup do
    :mnesia.start()
    Ash.DataLayer.Mnesia.start(AshGraphql.Test.Domain, [AshGraphql.Test.AfterTransactionMnesia])
    on_exit(fn -> :mnesia.clear_table(:after_transaction_mnesia_table) end)
  end

  describe "create mutation" do
    test "after_transaction is called on success" do
      """
      mutation CreateAfterTransactionMnesia($input: CreateAfterTransactionMnesiaInput!) {
        createAfterTransactionMnesia(input: $input) {
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
      mutation CreateAfterTransactionMnesiaWithError($input: CreateAfterTransactionMnesiaWithErrorInput!) {
        createAfterTransactionMnesiaWithError(input: $input) {
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

    test "record is not persisted when after_action fails" do
      """
      mutation CreateAfterTransactionMnesiaWithError($input: CreateAfterTransactionMnesiaWithErrorInput!) {
        createAfterTransactionMnesiaWithError(input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"name" => "should_not_exist"}}
      )

      assert AshGraphql.Test.AfterTransactionMnesia |> Ash.read!() |> Enum.empty?()
    end
  end

  describe "update mutation" do
    test "after_transaction is called on success" do
      record =
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "original"})
        |> Ash.create!()

      """
      mutation UpdateAfterTransactionMnesia($id: ID!, $input: UpdateAfterTransactionMnesiaInput!) {
        updateAfterTransactionMnesia(id: $id, input: $input) {
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
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "original"})
        |> Ash.create!()

      """
      mutation UpdateAfterTransactionMnesiaWithError($id: ID!, $input: UpdateAfterTransactionMnesiaWithErrorInput!) {
        updateAfterTransactionMnesiaWithError(id: $id, input: $input) {
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

    test "record is not updated when after_action fails" do
      record =
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "original"})
        |> Ash.create!()

      """
      mutation UpdateAfterTransactionMnesiaWithError($id: ID!, $input: UpdateAfterTransactionMnesiaWithErrorInput!) {
        updateAfterTransactionMnesiaWithError(id: $id, input: $input) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id, "input" => %{"name" => "should_not_update"}}
      )

      assert Ash.get!(AshGraphql.Test.AfterTransactionMnesia, record.id).name == "original"
    end
  end

  describe "destroy mutation" do
    test "after_transaction is called on success" do
      record =
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "to_destroy"})
        |> Ash.create!()

      """
      mutation DestroyAfterTransactionMnesia($id: ID!) {
        destroyAfterTransactionMnesia(id: $id) {
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
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "to_destroy"})
        |> Ash.create!()

      """
      mutation DestroyAfterTransactionMnesiaWithError($id: ID!) {
        destroyAfterTransactionMnesiaWithError(id: $id) {
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

    test "record is not destroyed when after_action fails" do
      record =
        AshGraphql.Test.AfterTransactionMnesia
        |> Ash.Changeset.for_create(:create, %{name: "should_still_exist"})
        |> Ash.create!()

      """
      mutation DestroyAfterTransactionMnesiaWithError($id: ID!) {
        destroyAfterTransactionMnesiaWithError(id: $id) {
          result { id name }
          errors { message }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => record.id}
      )

      assert Ash.get!(AshGraphql.Test.AfterTransactionMnesia, record.id).name ==
               "should_still_exist"
    end
  end
end
