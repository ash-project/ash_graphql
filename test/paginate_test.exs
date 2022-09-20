defmodule AshGraphql.PaginateTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGraphql.Test.Post)
      Ash.DataLayer.Ets.stop(AshGraphql.Test.Comment)
    end)
  end

  describe "pagination" do
    setup do
      letters = ["a", "b", "c", "d", "e"]

      for text <- letters do
        post =
          AshGraphql.Test.Post
          |> Ash.Changeset.for_create(:create, text: text, published: true)
          |> AshGraphql.Test.Api.create!()

        for text <- letters do
          AshGraphql.Test.Comment
          |> Ash.Changeset.for_create(:create, text: text)
          |> Ash.Changeset.replace_relationship(:post, post)
          |> AshGraphql.Test.Api.create!()
        end
      end

      :ok
    end

    test "default_limit records are fetched" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(sort: [{field: TEXT}]) {
          count
          results{
            text
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5,
                    "results" => [
                      %{"text" => "a"},
                      %{"text" => "b"},
                      %{"text" => "c"},
                      %{"text" => "d"},
                      %{"text" => "e"}
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "without limit all records are fetched" do
      doc = """
      query PaginatedPostsLimitNotRequired {
        paginatedPostsLimitNotRequired(sort: [{field: TEXT}]) {
          count
          results{
            text
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPostsLimitNotRequired" => %{
                    "count" => 5,
                    "results" => [
                      %{"text" => "a"},
                      %{"text" => "b"},
                      %{"text" => "c"},
                      %{"text" => "d"},
                      %{"text" => "e"}
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "the first can be fetched" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(limit: 1, sort: [{field: TEXT}]) {
          count
          results{
            text
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5,
                    "results" => [
                      %{"text" => "a"}
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "the count can be fetched on its own" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(limit: 1) {
          count
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "it can be paged through" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(limit: 2, offset: 2, sort: [{field: TEXT}]) {
          count
          results{
            text
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5,
                    "results" => [
                      %{"text" => "c"},
                      %{"text" => "d"}
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "related items can be requested while paginating" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(limit: 2, offset: 2, sort: [{field: TEXT}]) {
          count
          results{
            text
            comments(sort:[{field: TEXT}]){
              text
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5,
                    "results" => [
                      %{
                        "text" => "c",
                        "comments" => [
                          %{"text" => "a"},
                          %{"text" => "b"},
                          %{"text" => "c"},
                          %{"text" => "d"},
                          %{"text" => "e"}
                        ]
                      },
                      %{
                        "text" => "d",
                        "comments" => [
                          %{"text" => "a"},
                          %{"text" => "b"},
                          %{"text" => "c"},
                          %{"text" => "d"},
                          %{"text" => "e"}
                        ]
                      }
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "related items can be limited and offset while paginating" do
      doc = """
      query PaginatedPosts {
        paginatedPosts(limit: 2, offset: 2, sort: [{field: TEXT}]) {
          count
          results{
            text
            comments(limit: 2, offset: 2, sort:[{field: TEXT}]){
              text
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "paginatedPosts" => %{
                    "count" => 5,
                    "results" => [
                      %{
                        "text" => "c",
                        "comments" => [
                          %{"text" => "c"},
                          %{"text" => "d"}
                        ]
                      },
                      %{
                        "text" => "d",
                        "comments" => [
                          %{"text" => "c"},
                          %{"text" => "d"}
                        ]
                      }
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end
  end

  describe "pagination errors" do
    test "required limit without explicit value" do
      doc = """
      query PaginatedPosts {
        paginatedPostsWithoutLimit(sort: [{field: TEXT}]) {
          count
          results{
            text
          }
        }
      }
      """

      assert {:ok,
              %{
                errors: [
                  %{
                    locations: [%{column: 3, line: 2}],
                    message: "In argument \"limit\": Expected type \"Int!\", found null."
                  }
                ]
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end
  end
end
