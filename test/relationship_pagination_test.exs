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

  test "works when nested" do
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
end
