# SPDX-FileCopyrightText: 2026 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.VerifyPaginateRelationshipWithTest do
  use ExUnit.Case, async: true

  alias AshGraphql.Resource.Verifiers.VerifyPaginateRelationshipWith
  alias Spark.Dsl.Transformer

  defmodule TestDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule ManualChildren do
    use Ash.Resource.ManualRelationship

    @impl true
    def load(records, _opts, _context) do
      {:ok, Map.new(records, &{&1.id, []})}
    end
  end

  defmodule BaseResource do
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshGraphql.Resource]

    graphql do
      type :manual_parent
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      has_many :children, __MODULE__ do
        public?(true)
        manual(ManualChildren)
      end
    end
  end

  defp dsl_state(paginate_relationship_with) do
    Transformer.set_option(
      BaseResource.spark_dsl_config(),
      [:graphql],
      :paginate_relationship_with,
      paginate_relationship_with
    )
  end

  test "raises when a manual relationship is given a pagination strategy" do
    for strategy <- [:offset, :keyset, :relay] do
      assert_raise Spark.Error.DslError, ~r/children is a manual relationship/, fn ->
        VerifyPaginateRelationshipWith.verify(dsl_state(children: strategy))
      end
    end
  end

  test "allows a manual relationship to be unpaginated" do
    for strategy <- [nil, :none] do
      assert :ok = VerifyPaginateRelationshipWith.verify(dsl_state(children: strategy))
    end
  end
end
