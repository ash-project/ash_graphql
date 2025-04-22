defmodule AshGraphql.LazyInitTestPostSearchTest do
  use ExUnit.Case, async: false

  require Ash.Query

  setup do
    on_exit(fn ->
      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  describe "lazyinit post search" do
    setup do
      letters = ["a", "b", "c", "d", "e"]

      for text <- letters do
        post =
          AshGraphql.Test.Post
          |> Ash.Changeset.for_create(:create, text: text, published: true)
          |> Ash.create!()

        for text <- letters do
          AshGraphql.Test.Comment
          |> Ash.Changeset.for_create(:create, text: text)
          |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
          |> Ash.create!()
        end
      end

      :ok
    end

    test "should self reference predicate" do
      resp =
        """
        query LazyinitSearch($predicate: PredicateInput) {
          lazyinitSearch(predicate: $predicate) {
            text
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema,
          variables: %{
            "predicate" => %{
              "condition" => "and",
              "predicates" => [
                %{
                  "operator" => "eq",
                  "field" => "text",
                  "value" => "a"
                },
                %{
                  "condition" => "eq",
                  "field" => "text",
                  "value" => "b"
                }
              ]
            }
          }
        )

      assert {:ok, %{data: _}} = resp
    end
  end
end
