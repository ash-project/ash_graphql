# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.RelationshipPaginationTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "works with :relay strategy" do
    movie =
      AshGraphql.Test.Movie
      |> Ash.Changeset.for_create(:create, title: "Foo")
      |> Ash.create!()

    for i <- 1..5 do
      AshGraphql.Test.Actor
      |> Ash.Changeset.for_create(:create, name: "Actor #{i}")
      |> Ash.Changeset.manage_relationship(:movies, movie, type: :append)
      |> Ash.create!()
    end

    document =
      """
      query Movies($first: Int, $after: String) {
        getMovies {
          actors(first: $first, after: $after, sort: [{field: NAME}]) {
            pageInfo {
              hasNextPage
              hasPreviousPage
              startCursor
              endCursor
            }
            count
            edges {
              cursor
              node {
                name
              }
            }
          }
        }
      }
      """

    resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"first" => 1})
    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "getMovies" => [
                 %{
                   "actors" => %{
                     "count" => 5,
                     "edges" => [%{"cursor" => cursor, "node" => %{"name" => "Actor 1"}}],
                     "pageInfo" => %{
                       "hasPreviousPage" => false,
                       "hasNextPage" => true
                     }
                   }
                 }
               ]
             }
           } = result

    resp =
      Absinthe.run(document, AshGraphql.Test.Schema,
        variables: %{"first" => 4, "after" => cursor}
      )

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "getMovies" => [
                 %{
                   "actors" => %{
                     "edges" => edges,
                     "pageInfo" => %{
                       "hasPreviousPage" => true,
                       "hasNextPage" => false
                     }
                   }
                 }
               ]
             }
           } = result

    assert length(edges) == 4
    assert [%{"node" => %{"name" => "Actor 2"}} | _] = edges
  end

  test "works with :offset strategy" do
    movie =
      AshGraphql.Test.Movie
      |> Ash.Changeset.for_create(:create, title: "Foo")
      |> Ash.create!()

    for i <- 1..5 do
      AshGraphql.Test.Review
      |> Ash.Changeset.for_create(:create, text: "Review #{i}")
      |> Ash.Changeset.manage_relationship(:movie, movie, type: :append)
      |> Ash.create!()
    end

    document =
      """
      query Movies($limit: Int, $offset: Int) {
        getMovies {
          reviews(limit: $limit, offset: $offset, sort: [{field: TEXT}]) {
            results {
              text
            }
            count
            hasNextPage
          }
        }
      }
      """

    resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"limit" => 1})
    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "getMovies" => [
                 %{
                   "reviews" => %{
                     "count" => 5,
                     "results" => [%{"text" => "Review 1"}],
                     "hasNextPage" => true
                   }
                 }
               ]
             }
           } = result

    resp =
      Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"limit" => 4, "offset" => 1})

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "getMovies" => [
                 %{
                   "reviews" => %{
                     "results" => results,
                     "hasNextPage" => false
                   }
                 }
               ]
             }
           } = result

    assert length(results) == 4
    assert [%{"text" => "Review 2"} | _] = results
  end

  test "works with :keyset strategy" do
    movie =
      AshGraphql.Test.Movie
      |> Ash.Changeset.for_create(:create, title: "Foo")
      |> Ash.create!()

    for i <- 1..5 do
      AshGraphql.Test.Award
      |> Ash.Changeset.for_create(:create, name: "Award #{i}")
      |> Ash.Changeset.manage_relationship(:movie, movie, type: :append)
      |> Ash.create!()
    end

    document =
      """
      query Movies($first: Int, $after: String) {
        getMovies {
          awards(first: $first, after: $after, sort: [{field: NAME}]) {
            results {
              name
            }
            count
            endKeyset
          }
        }
      }
      """

    resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"first" => 1})
    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "getMovies" => [
                 %{
                   "awards" => %{
                     "count" => 5,
                     "results" => [%{"name" => "Award 1"}],
                     "endKeyset" => cursor
                   }
                 }
               ]
             }
           } = result

    resp =
      Absinthe.run(document, AshGraphql.Test.Schema,
        variables: %{"first" => 4, "after" => cursor}
      )

    assert {:ok, result} = resp
    refute Map.has_key?(result, :errors)

    assert %{data: %{"getMovies" => [%{"awards" => %{"results" => results}}]}} = result

    assert length(results) == 4
    assert [%{"name" => "Award 2"} | _] = results
  end

  describe ":none strategy" do
    setup do
      %{id: post_id} =
        AshGraphql.Test.Post
        |> Ash.Changeset.for_create(:create, text: "Post", published: true, score: 9.8)
        |> Ash.create!()

      [post_id: post_id]
    end

    test "works with :none strategy", %{post_id: post_id} do
      document =
        """
        query GetPost($id: ID!) {
          getPost(id: $id) {
            id
            unpaginatedComments {
              id
            }
          }
        }
        """

      assert {:ok,
              %{
                data: %{
                  "getPost" => %{
                    "unpaginatedComments" => [],
                    "id" => ^post_id
                  }
                }
              }} =
               Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"id" => post_id})
    end

    test "can't supply limit/offset with :none strategy", %{post_id: post_id} do
      document =
        """
        query GetPost($id: ID!) {
          getPost(id: $id) {
            id
            unpaginatedComments(limit: 1, offset: 0) {
              id
            }
          }
        }
        """

      assert {:ok,
              %{
                errors: [
                  %{
                    message:
                      "Unknown argument \"limit\" on field \"unpaginatedComments\" of type \"Post\"."
                  },
                  %{
                    message:
                      "Unknown argument \"offset\" on field \"unpaginatedComments\" of type \"Post\"."
                  }
                ]
              }} =
               Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"id" => post_id})
    end
  end

  describe "works when nested" do
    test "on return values for queries" do
      movie =
        AshGraphql.Test.Movie
        |> Ash.Changeset.for_create(:create, title: "Movie")
        |> Ash.create!()

      agents =
        for i <- 1..4 do
          AshGraphql.Test.Agent
          |> Ash.Changeset.for_create(:create, name: "Agent #{i}")
          |> Ash.create!()
        end

      for i <- 1..5 do
        AshGraphql.Test.Actor
        |> Ash.Changeset.for_create(:create, name: "Actor #{i}")
        |> Ash.Changeset.manage_relationship(:movies, movie, type: :append)
        |> Ash.Changeset.manage_relationship(:agents, agents, type: :append)
        |> Ash.create!()
      end

      document =
        """
        query Movies($first: Int, $after: String) {
          getMovies(sort: [{field: TITLE}]) {
            actors(first: 1, sort: [{field: NAME}]) {
              count
              edges {
                cursor
                node {
                  name
                  agents(first: $first, after: $after, sort: [{field: NAME}]) {
                    count
                    edges {
                      cursor
                      node {
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

      resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: %{"first" => 1})
      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "getMovies" => [
                   %{
                     "actors" => %{
                       "count" => 5,
                       "edges" => [
                         %{
                           "node" => %{
                             "name" => "Actor 1",
                             "agents" => %{
                               "count" => 4,
                               "edges" => [
                                 %{
                                   "cursor" => cursor,
                                   "node" => %{
                                     "name" => "Agent 1"
                                   }
                                 }
                               ]
                             }
                           }
                         }
                       ]
                     }
                   }
                 ]
               }
             } = result

      resp =
        Absinthe.run(document, AshGraphql.Test.Schema,
          variables: %{"first" => 3, "after" => cursor}
        )

      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "getMovies" => [
                   %{
                     "actors" => %{
                       "count" => 5,
                       "edges" => [
                         %{
                           "node" => %{
                             "name" => "Actor 1",
                             "agents" => %{
                               "count" => 4,
                               "edges" => edges
                             }
                           }
                         }
                       ]
                     }
                   }
                 ]
               }
             } = result

      assert length(edges) == 3
      assert [%{"node" => %{"name" => "Agent 2"}} | _] = edges
    end

    test "on return values for create mutations" do
      actor1 = Ash.create!(AshGraphql.Test.Actor, %{name: "Actor 1"})
      actor2 = Ash.create!(AshGraphql.Test.Actor, %{name: "Actor 2"})

      document =
        """
        mutation CreateMovie($input: CreateMovieInput!, $first: Int, $after: String) {
          createMovie(input: $input) {
            result {
              title
              actors(first: $first, after: $after, sort: [{field: NAME}]) {
                count
                edges {
                  cursor
                  node {
                    name
                  }
                }
              }
            }
          }
        }
        """

      variables = %{
        "input" => %{"title" => "Movie 1", "actorIds" => [actor2.id, actor1.id]},
        "first" => 1
      }

      resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: variables)
      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "createMovie" => %{
                   "result" => %{
                     "title" => "Movie 1",
                     "actors" => %{
                       "count" => 2,
                       "edges" => [
                         %{
                           "cursor" => cursor,
                           "node" => %{
                             "name" => "Actor 1"
                           }
                         }
                       ]
                     }
                   }
                 }
               }
             } = result

      variables = %{
        "input" => %{"title" => "Movie 2", "actorIds" => [actor2.id, actor1.id]},
        "first" => 2,
        "after" => cursor
      }

      resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: variables)
      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "createMovie" => %{
                   "result" => %{
                     "title" => "Movie 2",
                     "actors" => %{
                       "count" => 2,
                       "edges" => [
                         %{
                           "node" => %{
                             "name" => "Actor 2"
                           }
                         }
                       ]
                     }
                   }
                 }
               }
             } = result
    end

    test "on return values for update mutations" do
      movie =
        AshGraphql.Test.Movie
        |> Ash.Changeset.for_create(:create, title: "Title")
        |> Ash.create!()

      for i <- 1..5 do
        AshGraphql.Test.Actor
        |> Ash.Changeset.for_create(:create, name: "Actor #{i}")
        |> Ash.Changeset.manage_relationship(:movies, movie, type: :append)
        |> Ash.create!()
      end

      document =
        """
        mutation UpdateMovie($id: ID!, $input: UpdateMovieInput!, $first: Int, $after: String) {
          updateMovie(id: $id, input: $input) {
            result {
              title
              actors(first: $first, after: $after, sort: [{field: NAME}]) {
                count
                edges {
                  cursor
                  node {
                    name
                  }
                }
              }
            }
          }
        }
        """

      variables = %{"id" => movie.id, "input" => %{"title" => "Updated Title 1"}, "first" => 1}
      resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: variables)
      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "updateMovie" => %{
                   "result" => %{
                     "title" => "Updated Title 1",
                     "actors" => %{
                       "count" => 5,
                       "edges" => [
                         %{
                           "cursor" => cursor,
                           "node" => %{
                             "name" => "Actor 1"
                           }
                         }
                       ]
                     }
                   }
                 }
               }
             } = result

      variables = %{
        "id" => movie.id,
        "input" => %{"title" => "Updated Title 2"},
        "first" => 3,
        "after" => cursor
      }

      resp = Absinthe.run(document, AshGraphql.Test.Schema, variables: variables)

      assert {:ok, result} = resp
      refute Map.has_key?(result, :errors)

      assert %{
               data: %{
                 "updateMovie" => %{
                   "result" => %{
                     "title" => "Updated Title 2",
                     "actors" => %{
                       "count" => 5,
                       "edges" => [
                         %{
                           "node" => %{
                             "name" => "Actor 2"
                           }
                         },
                         %{
                           "node" => %{
                             "name" => "Actor 3"
                           }
                         },
                         %{
                           "node" => %{
                             "name" => "Actor 4"
                           }
                         }
                       ]
                     }
                   }
                 }
               }
             } = result
    end
  end
end
