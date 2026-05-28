# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MissingRelatedDomainTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # Define RelatedResource, RelatedDomain, SourceResource, and SourceDomain as valid,
  # fully-compiled modules outside of the test.
  # The test scenario is: both domains are valid, but the schema only registers SourceDomain.

  alias AshGraphql.MissingRelatedDomainTest.{
    AggregateTypoChild,
    AggregateTypoDomain,
    AggregateTypoParent,
    RelatedDomain,
    RelatedResource,
    SourceDomain,
    SourceResource
  }

  defmodule RelatedResource do
    use Ash.Resource,
      domain: RelatedDomain,
      extensions: [AshGraphql.Resource]

    graphql do
      type :missing_test_related_resource
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end
  end

  defmodule RelatedDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      resource(RelatedResource)
    end
  end

  defmodule SourceResource do
    use Ash.Resource,
      domain: SourceDomain,
      extensions: [AshGraphql.Resource]

    graphql do
      type :missing_test_source_resource

      queries do
        list :list_source_resources, :read
      end
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:related, RelatedResource, public?: true)
    end
  end

  defmodule SourceDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      resource(SourceResource)
    end
  end

  defmodule AggregateTypoChild do
    use Ash.Resource,
      domain: AggregateTypoDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    graphql do
      type :agg_typo_child
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:parent_id, :uuid, public?: true)
      create_timestamp(:created_at, public?: true)
    end

    calculations do
      calculate :timestamp, :utc_datetime_usec, expr(created_at) do
        public?(true)
      end
    end
  end

  defmodule AggregateTypoParent do
    use Ash.Resource,
      domain: AggregateTypoDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshGraphql.Resource]

    graphql do
      type :agg_typo_parent

      queries do
        list :list_parents, :read
      end
    end

    actions do
      default_accept(:*)
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      has_many :children, AggregateTypoChild do
        public?(true)
        destination_attribute(:parent_id)
      end
    end

    aggregates do
      max(:latest_child_at, [:children], :time_stamp, public?: true)
    end
  end

  defmodule AggregateTypoDomain do
    use Ash.Domain, extensions: [AshGraphql.Domain]

    resources do
      resource(AggregateTypoParent)
      resource(AggregateTypoChild)
    end
  end

  test "raises at compile time when a related resource's domain is not in the schema" do
    assert_raise RuntimeError, ~r/RelatedDomain/, fn ->
      defmodule TestSchemaMissingDomain do
        use Absinthe.Schema

        # Only SourceDomain is registered — RelatedDomain is intentionally omitted
        @domains [SourceDomain]
        use AshGraphql, domains: @domains
      end
    end
  end

  test "typoed aggregate field raises a helpful DSL error" do
    capture_io(:stderr, fn ->
      assert_raise Spark.Error.DslError, ~r/:time_stamp/, fn ->
        defmodule TestSchemaAggregateFieldTypo do
          use Absinthe.Schema
          use AshGraphql, domains: [AggregateTypoDomain]
        end
      end
    end)
  end
end
