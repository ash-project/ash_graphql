# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MetaTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "meta attibute for query" do
    test "should inlcude the meta keywordlist in the context" do
      movie =
        AshGraphql.Test.Movie
        |> Ash.Changeset.for_create(:create, title: "Title")
        |> Ash.create!()

      """
      query getMovie {
        getMovie(id: "#{movie.id}") {
          id
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

      assert_receive {:test_meta, :meta_string, "bar"}
      assert_receive {:test_meta, :meta_integer, 1}
    end
  end

  describe "meta attibute for mutation" do
    test "should inlcude the meta keywordlist in the context" do
      movie =
        AshGraphql.Test.Movie
        |> Ash.Changeset.for_create(:create, title: "Title")
        |> Ash.create!()

      """
       mutation UpdateMovie($id: ID!, $input: UpdateMovieInput!) {
        updateMovie(id: $id, input: $input) {
          result {
            title
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"id" => movie.id, "input" => %{"title" => "Updated Title 1"}}
      )

      assert_receive {:test_meta, :meta_string, "bar"}
      assert_receive {:test_meta, :meta_integer, 1}
    end
  end

  describe "meta attibute for subscription" do
    test "should inlcude the meta keywordlist in the context" do
      """
      mutation CreateSubscribable($input: CreateSubscribableInput) {
          createSubscribable(input: $input) {
            result{
              id
              text
            }
            errors{
              message
            }
          }
        }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"text" => "foo"}}
      )

      assert_receive {:test_meta, :meta_string, "bar"}
      assert_receive {:test_meta, :meta_integer, 1}
    end
  end
end
