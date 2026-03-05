# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.DataLayer.EtsWithFunctions do
  @moduledoc false
  @behaviour Ash.DataLayer

  @ets_with_functions %Spark.Dsl.Section{
    name: :ets_with_functions,
    describe: "ETS data layer with custom functions for testing",
    schema: [
      private?: [
        type: :boolean,
        default: false
      ],
      table: [
        type: :atom
      ],
      repo: [
        type: :atom,
        doc: "A fake repo option to simulate AshPostgres pattern"
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@ets_with_functions]

  @impl true
  defdelegate can?(resource, feature), to: Ash.DataLayer.Ets

  @impl true
  defdelegate resource_to_query(resource, domain), to: Ash.DataLayer.Ets

  @impl true
  defdelegate limit(query, limit, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate offset(query, offset, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate add_calculations(query, calculations, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate add_aggregate(query, aggregate, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate set_tenant(resource, query, tenant), to: Ash.DataLayer.Ets

  @impl true
  defdelegate set_context(resource, query, context), to: Ash.DataLayer.Ets

  @impl true
  defdelegate select(query, select, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate filter(query, filter, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate sort(query, sort, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate distinct(query, distinct, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate distinct_sort(query, distinct_sort, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate run_query(query, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate run_aggregate_query(query, aggregates, resource), to: Ash.DataLayer.Ets

  @impl true
  defdelegate create(resource, changeset), to: Ash.DataLayer.Ets

  @impl true
  defdelegate destroy(resource, changeset), to: Ash.DataLayer.Ets

  @impl true
  defdelegate update(resource, changeset), to: Ash.DataLayer.Ets

  @impl true
  defdelegate combination_of(combinations, resource, domain), to: Ash.DataLayer.Ets

  @impl true
  defdelegate prefer_lateral_join_for_many_to_many?, to: Ash.DataLayer.Ets

  @impl true
  defdelegate calculate(resource, expressions, context), to: Ash.DataLayer.Ets

  @impl true
  def functions(resource) do
    # Simulate AshPostgres pattern: access a DSL option, then call a method on it
    # AshPostgres does: AshPostgres.DataLayer.Info.repo(resource, :mutate).config()
    repo = Spark.Dsl.Extension.get_opt(resource, [:ets_with_functions], :repo, nil, true)

    if repo do
      _config = repo.config()
    end

    [AshGraphql.Test.Functions.TestILike]
  end
end
