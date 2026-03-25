# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Transformers.FlattenQueryMutationGroups do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias AshGraphql.Resource.{Action, Mutation, MutationGroup, Query, QueryGroup}
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Transformer

  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module)

    dsl =
      dsl
      |> replace_section_entities!([:graphql, :queries], &flatten_queries(&1, module))
      |> replace_section_entities!([:graphql, :mutations], &flatten_mutations(&1, module))

    {:ok, dsl}
  end

  # Spark keeps each DSL section at `dsl[path]` as `%{entities: [...], opts: [...], ...}`.
  # `Transformer.get_entities/2` and `Map.update/4` match how `add_entity/3` and `get_entities/2`
  # are implemented in Spark — we only replace `:entities` and preserve opts/annotations.
  defp replace_section_entities!(dsl, path, fun) do
    entities = Transformer.get_entities(dsl, path)
    new_entities = fun.(entities)

    Map.update(
      dsl,
      path,
      Map.put(Extension.default_section_config(), :entities, new_entities),
      fn config -> %{config | entities: new_entities} end
    )
  end

  defp flatten_queries(entities, module) do
    entities
    |> Enum.flat_map(&expand_query_entity(&1, module))
    |> tap(&assert_unique_grouped_names!(&1, module, :queries))
  end

  defp flatten_mutations(entities, module) do
    entities
    |> Enum.flat_map(&expand_mutation_entity(&1, module))
    |> tap(&assert_unique_grouped_names!(&1, module, :mutations))
  end

  defp expand_query_entity(%QueryGroup{} = g, module) do
    Enum.map(g.queries, fn
      %QueryGroup{} ->
        raise Spark.Error.DslError,
          module: module,
          message: "Nested `group` inside `queries` is not supported (only one level of grouping is allowed)."

      %MutationGroup{} ->
        raise Spark.Error.DslError,
          module: module,
          message: "Mutation `group` cannot appear inside a query `group`."

      %Query{} = q ->
        %{q | group: g.name}

      %Action{} = a ->
        %{a | group: g.name}

      other ->
        raise Spark.Error.DslError,
          module: module,
          message:
            "Unexpected entity inside query `group` (expected get/read_one/list/action): #{inspect(other.__struct__)}"
    end)
  end

  defp expand_query_entity(%Query{} = q, _), do: [q]
  defp expand_query_entity(%Action{} = q, _), do: [q]

  defp expand_query_entity(other, module) do
    raise Spark.Error.DslError,
      module: module,
      message: "Unexpected entity in queries section: #{inspect(other.__struct__)}"
  end

  defp expand_mutation_entity(%MutationGroup{} = g, module) do
    Enum.map(g.mutations, fn
      %MutationGroup{} ->
        raise Spark.Error.DslError,
          module: module,
          message: "Nested `group` inside `mutations` is not supported (only one level of grouping is allowed)."

      %QueryGroup{} ->
        raise Spark.Error.DslError,
          module: module,
          message: "Query `group` cannot appear inside a mutation `group`."

      %Mutation{} = m ->
        %{m | group: g.name}

      %Action{} = a ->
        %{a | group: g.name}

      other ->
        raise Spark.Error.DslError,
          module: module,
          message:
            "Unexpected entity inside mutation `group` (expected create/update/destroy/action): #{inspect(other.__struct__)}"
    end)
  end

  defp expand_mutation_entity(%Mutation{} = m, _), do: [m]
  defp expand_mutation_entity(%Action{} = m, _), do: [m]

  defp expand_mutation_entity(other, module) do
    raise Spark.Error.DslError,
      module: module,
      message: "Unexpected entity in mutations section: #{inspect(other.__struct__)}"
  end

  defp assert_unique_grouped_names!(entities, module, :queries) do
    entities
    |> Enum.filter(&(match?(%Query{}, &1) or match?(%Action{}, &1)))
    |> Enum.group_by(fn q -> {q.group, q.name} end)
    |> Enum.each(fn
      {{nil, _}, _} ->
        :ok

      {{group, name}, list} ->
        if length(list) > 1 do
          raise Spark.Error.DslError,
            module: module,
            message:
              "Duplicate GraphQL query field `#{name}` inside query group `#{inspect(group)}`. " <>
                "Merged groups (same name) cannot expose the same field name twice."
        end
    end)
  end

  defp assert_unique_grouped_names!(entities, module, :mutations) do
    entities
    |> Enum.filter(&(match?(%Mutation{}, &1) or match?(%Action{}, &1)))
    |> Enum.group_by(fn m -> {m.group, m.name} end)
    |> Enum.each(fn
      {{nil, _}, _} ->
        :ok

      {{group, name}, list} ->
        if length(list) > 1 do
          raise Spark.Error.DslError,
            module: module,
            message:
              "Duplicate GraphQL mutation field `#{name}` inside mutation group `#{inspect(group)}`. " <>
                "Merged groups (same name) cannot expose the same field name twice."
        end
    end)
  end
end
