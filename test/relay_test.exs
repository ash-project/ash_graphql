defmodule AshGraphql.RelayTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "relay" do
    setup do
      letters = ["a", "b", "c", "d", "e"]

      for name <- letters do
        tag =
          AshGraphql.Test.RelayTag
          |> Ash.Changeset.for_create(
            :create,
            name: name
          )
          |> Ash.create!()

        for text <- letters do
          AshGraphql.Test.Post
          |> Ash.Changeset.for_create(:create, text: text, published: true)
          |> Ash.Changeset.manage_relationship(
            :relay_tags,
            [tag],
            on_no_match: :error,
            on_lookup: :relate_and_update
          )
          |> Ash.create!()
        end
      end

      :ok
    end

    test "neither first nor last passed" do
      page = """
      query PaginatedPosts {
        getRelayTags(sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          count
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "count" => 5,
                    "pageInfo" => %{
                      "hasNextPage" => false,
                      "hasPreviousPage" => false,
                      "startCursor" => start_cursor,
                      "endCursor" => end_cursor
                    },
                    # relay returned all the records
                    "edges" => [
                      %{
                        "cursor" => start_cursor,
                        "node" => %{"name" => "a"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "b"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "c"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "d"}
                      },
                      %{
                        "cursor" => end_cursor,
                        "node" => %{"name" => "e"}
                      }
                    ]
                  }
                }
              }} = Absinthe.run(page, AshGraphql.Test.Schema)
    end

    test "first page contains few records" do
      page = """
      query PaginatedPosts {
        getRelayTags(first: 2, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => true,
                      "hasPreviousPage" => false,
                      "startCursor" => start_cursor,
                      "endCursor" => end_cursor
                    },
                    # relay returned only first 2 records
                    "edges" => [
                      %{
                        "cursor" => start_cursor,
                        "node" => %{"name" => "a"}
                      },
                      %{
                        "cursor" => end_cursor,
                        "node" => %{"name" => "b"}
                      }
                    ]
                  }
                }
              }} = Absinthe.run(page, AshGraphql.Test.Schema)
    end

    test "first page contains all records" do
      doc = """
      query PaginatedPosts {
        getRelayTags(first: 6, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => false,
                      "hasPreviousPage" => false,
                      "startCursor" => start_cursor,
                      "endCursor" => end_cursor
                    },
                    # relay returned all the records
                    "edges" => [
                      %{
                        "cursor" => start_cursor,
                        "node" => %{"name" => "a"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "b"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "c"}
                      },
                      %{
                        "cursor" => _,
                        "node" => %{"name" => "d"}
                      },
                      %{
                        "cursor" => end_cursor,
                        "node" => %{"name" => "e"}
                      }
                    ]
                  }
                }
              }} = Absinthe.run(doc, AshGraphql.Test.Schema)
    end

    test "first with starting cursor" do
      page = """
      query PaginatedPosts($after: String) {
        getRelayTags(first: 2, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "a" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "startCursor" => start_cursor1
             }
           }
         }
       }} = Absinthe.run(page, AshGraphql.Test.Schema)

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => true,
                      "hasPreviousPage" => true,
                      "startCursor" => start_cursor2,
                      "endCursor" => end_cursor2
                    },
                    # relay returned only first 2 records
                    "edges" => [
                      %{
                        "cursor" => start_cursor2,
                        "node" => %{"name" => "b"}
                      },
                      %{
                        "cursor" => end_cursor2,
                        "node" => %{"name" => "c"}
                      }
                    ]
                  }
                }
              }} =
               Absinthe.run(page, AshGraphql.Test.Schema, variables: %{"after" => start_cursor1})

      assert start_cursor1 != start_cursor2
    end

    test "first with middle cursor" do
      page = """
      query PaginatedPosts($after: String) {
        getRelayTags(first: 2, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "b" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "endCursor" => end_cursor1
             }
           }
         }
       }} = Absinthe.run(page, AshGraphql.Test.Schema)

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => true,
                      "hasPreviousPage" => true,
                      "startCursor" => start_cursor2,
                      "endCursor" => end_cursor2
                    },
                    # relay returned only first 2 records
                    "edges" => [
                      %{
                        "cursor" => start_cursor2,
                        "node" => %{"name" => "c"}
                      },
                      %{
                        "cursor" => end_cursor2,
                        "node" => %{"name" => "d"}
                      }
                    ]
                  }
                }
              }} =
               Absinthe.run(page, AshGraphql.Test.Schema, variables: %{"after" => end_cursor1})

      assert end_cursor1 != start_cursor2
      assert end_cursor1 != end_cursor2
    end

    test "first with final cursor" do
      page = """
      query PaginatedPosts($after: String) {
        getRelayTags(first: 20, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "f" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "endCursor" => end_cursor1
             }
           }
         }
       }} = Absinthe.run(page, AshGraphql.Test.Schema)

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => false,
                      "hasPreviousPage" => true,
                      "startCursor" => nil,
                      "endCursor" => nil
                    },
                    "edges" => []
                  }
                }
              }} =
               Absinthe.run(page, AshGraphql.Test.Schema, variables: %{"after" => end_cursor1})
    end

    test "last with starting cursor" do
      page1 = """
      query PaginatedPosts {
        getRelayTags(first: 1, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "a" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "startCursor" => start_cursor1
             }
           }
         }
       }} = Absinthe.run(page1, AshGraphql.Test.Schema)

      page2 = """
      query PaginatedPosts($before: String) {
        getRelayTags(last: 2, before: $before, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => false,
                      "hasPreviousPage" => false,
                      "endCursor" => nil,
                      "startCursor" => nil
                    },
                    "edges" => []
                  }
                }
              }} =
               Absinthe.run(page2, AshGraphql.Test.Schema,
                 variables: %{"before" => start_cursor1}
               )
    end

    test "last with middle cursor" do
      page1 = """
      query PaginatedPosts($after: String) {
        getRelayTags(first: 3, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "c" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "endCursor" => end_cursor1
             }
           }
         }
       }} = Absinthe.run(page1, AshGraphql.Test.Schema)

      page2 = """
      query PaginatedPosts($before: String) {
        getRelayTags(last: 1, before: $before, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      "hasNextPage" => true,
                      "hasPreviousPage" => true,
                      "startCursor" => start_cursor2,
                      "endCursor" => start_cursor2
                    },
                    "edges" => [
                      %{
                        "cursor" => start_cursor2,
                        "node" => %{"name" => "b"}
                      }
                    ]
                  }
                }
              }} =
               Absinthe.run(page2, AshGraphql.Test.Schema, variables: %{"before" => end_cursor1})

      assert end_cursor1 != start_cursor2
    end

    test "last with final cursor" do
      page1 = """
      query PaginatedPosts {
        getRelayTags(first: 20, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      # cursor is matching "e" tag
      {:ok,
       %{
         data: %{
           "getRelayTags" => %{
             "pageInfo" => %{
               "endCursor" => end_cursor1
             }
           }
         }
       }} = Absinthe.run(page1, AshGraphql.Test.Schema)

      page2 = """
      query PaginatedPosts($before: String) {
        getRelayTags(last: 2, before: $before, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {:ok,
              %{
                data: %{
                  "getRelayTags" => %{
                    "pageInfo" => %{
                      # item matching 'before' cursor (== "e") is not returned
                      # but it can be fetched using first + after + endCursor of current page
                      "hasNextPage" => true,
                      "hasPreviousPage" => true,
                      "startCursor" => start_cursor2,
                      "endCursor" => end_cursor2
                    },
                    # relay returned only last 2 records
                    "edges" => [
                      %{
                        "cursor" => start_cursor2,
                        "node" => %{"name" => "c"}
                      },
                      %{
                        "cursor" => end_cursor2,
                        "node" => %{"name" => "d"}
                      }
                    ]
                  }
                }
              }} =
               Absinthe.run(page2, AshGraphql.Test.Schema, variables: %{"before" => end_cursor1})

      assert end_cursor1 != start_cursor2
      assert end_cursor1 != end_cursor2
    end
  end

  describe "relay errors" do
    test "both first and last are passed" do
      page = """
      query PaginatedPosts {
        getRelayTags(last: 2, first: 10, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message: "You can pass either `first` or `last`, not both",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } = Absinthe.run(page, AshGraphql.Test.Schema)
    end

    test "last without before cursor" do
      page = """
      query PaginatedPosts {
        getRelayTags(last: 2, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message: "You can pass `last` only with `before` cursor",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } = Absinthe.run(page, AshGraphql.Test.Schema)
    end

    test "wrong first/last with after/before combinations" do
      page = """
      query PaginatedPosts($first: Int, $last: Int, $before: String, $after: String) {
        getRelayTags(first: $first, last: $last, before: $before, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message:
                       "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } =
               Absinthe.run(page, AshGraphql.Test.Schema,
                 variables: %{"first" => 20, "before" => "abc"}
               )

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message:
                       "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } =
               Absinthe.run(page, AshGraphql.Test.Schema,
                 variables: %{"first" => 20, "after" => "abc", "before" => "abc"}
               )

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message:
                       "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } =
               Absinthe.run(page, AshGraphql.Test.Schema,
                 variables: %{"last" => 20, "after" => "abc"}
               )

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message:
                       "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } =
               Absinthe.run(page, AshGraphql.Test.Schema,
                 variables: %{"last" => 20, "after" => "abc", "before" => "abc"}
               )
    end

    # return readable error message
    test "invalid after cursor" do
      page = """
      query PaginatedPosts($after: String) {
        getRelayTags(first: 2, after: $after, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message: "Invalid value provided as a keyset for after: \"abc\"",
                     short_message: "invalid keyset",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } = Absinthe.run(page, AshGraphql.Test.Schema, variables: %{"after" => "abc"})
    end

    test "invalid before cursor" do
      page = """
      query PaginatedPosts($before: String) {
        getRelayTags(last: 1, before: $before, sort: [{field: NAME}]) {
          pageInfo {
            hasNextPage
            hasPreviousPage
            startCursor
            endCursor
          }
          edges{
            cursor
            node {
              name
            }
          }
        }
      }
      """

      assert {
               :ok,
               %{
                 data: %{"getRelayTags" => nil},
                 errors: [
                   %{
                     locations: [%{column: 3, line: 2}],
                     message: "Invalid value provided as a keyset for before: \"abc\"",
                     short_message: "invalid keyset",
                     path: ["getRelayTags"]
                   }
                 ]
               }
             } = Absinthe.run(page, AshGraphql.Test.Schema, variables: %{"before" => "abc"})
    end
  end
end
