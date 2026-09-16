# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.PageSizeTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)

    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "post", published: true)
      |> Ash.create!()

    AshGraphql.Test.Comment
    |> Ash.Changeset.for_create(:create, text: "comment")
    |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
    |> Ash.create!()

    :ok
  end

  describe "offset pagination" do
    test "a zero or negative limit is a rendered error" do
      for limit <- [0, -1] do
        assert {:ok,
                %{
                  data: %{"paginatedPosts" => nil},
                  errors: [%{message: "`limit` must be a positive integer"}]
                }} =
                 Absinthe.run(
                   "query { paginatedPosts(limit: #{limit}) { results { text } } }",
                   AshGraphql.Test.Schema
                 )
      end
    end
  end

  describe "keyset pagination" do
    test "a zero or negative first is a rendered error" do
      for first <- [0, -1] do
        assert {:ok,
                %{
                  data: %{"keysetPaginatedPosts" => nil},
                  errors: [%{message: "`first` must be a positive integer"}]
                }} =
                 Absinthe.run(
                   "query { keysetPaginatedPosts(first: #{first}) { results { text } } }",
                   AshGraphql.Test.Schema
                 )
      end
    end

    test "a zero or negative last is a rendered error" do
      for last <- [0, -1] do
        assert {:ok,
                %{
                  data: %{"keysetPaginatedPosts" => nil},
                  errors: [%{message: "`last` must be a positive integer"}]
                }} =
                 Absinthe.run(
                   ~s|query { keysetPaginatedPosts(last: #{last}, before: "x") { results { text } } }|,
                   AshGraphql.Test.Schema
                 )
      end
    end
  end

  describe "complexity analysis" do
    test "a negative page size does not crash the analyzer" do
      for query <- [
            "query { paginatedPosts(limit: -1) { results { text } } }",
            "query { keysetPaginatedPosts(first: -1) { results { text } } }"
          ] do
        assert {:ok, %{errors: [%{message: message}]}} =
                 Absinthe.run(query, AshGraphql.Test.Schema,
                   analyze_complexity: true,
                   max_complexity: 100
                 )

        assert message =~ "must be a positive integer"
      end
    end
  end

  describe "relationship arguments" do
    test "a negative limit is a rendered error and a zero limit is an empty list" do
      assert {:ok, %{errors: [%{message: "`limit` must not be negative"}]}} =
               Absinthe.run(
                 "query { paginatedPosts(limit: 1) { results { comments(limit: -1) { text } } } }",
                 AshGraphql.Test.Schema
               )

      assert {:ok, %{data: %{"paginatedPosts" => %{"results" => [%{"comments" => []}]}}}} =
               Absinthe.run(
                 "query { paginatedPosts(limit: 1) { results { comments(limit: 0) { text } } } }",
                 AshGraphql.Test.Schema
               )
    end
  end
end
