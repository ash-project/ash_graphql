# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.MissingRelatedDomainTest do
  use ExUnit.Case, async: false

  # Define RelatedResource, RelatedDomain, SourceResource, and SourceDomain as valid,
  # fully-compiled modules outside of the test.
  # The test scenario is: both domains are valid, but the schema only registers SourceDomain.

  alias AshGraphql.MissingRelatedDomainTest.{
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
end
