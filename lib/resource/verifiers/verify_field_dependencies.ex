# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyFieldDependencies do
  # Validates cross-field dependencies between graphql DSL options.
  # For example, a field in sortable_fields that is hidden via hide_fields
  # will have no effect at runtime - this verifier warns about such cases.
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  @impl true
  def verify(dsl) do
    resource = Transformer.get_persisted(dsl, :module)
    show_fields = AshGraphql.Resource.Info.show_fields(dsl)
    hide_fields = AshGraphql.Resource.Info.hide_fields(dsl)

    # Hard error: show_fields and hide_fields must not overlap
    validate_show_hide_contradiction!(resource, show_fields, hide_fields)

    has_visibility_constraints = not (is_nil(show_fields) and is_nil(hide_fields))
    explicit_relationships = Spark.Dsl.Extension.get_opt(dsl, [:graphql], :relationships, nil)

    warnings =
      []
      |> then(fn warnings ->
        if has_visibility_constraints do
          visible = compute_visible_fields(dsl, show_fields, hide_fields)

          warnings
          |> check_invisible_fields(dsl, resource, visible, :sortable_fields, "sortable_fields")
          |> check_invisible_fields(
            dsl,
            resource,
            visible,
            :filterable_fields,
            "filterable_fields"
          )
          |> check_invisible_fields(
            dsl,
            resource,
            visible,
            :nullable_fields,
            "nullable_fields"
          )
          |> check_invisible_field_names(dsl, resource, visible)
          |> check_invisible_relationships(dsl, resource, visible)
          |> check_invisible_paginate_relationship_with(dsl, resource, visible)
          |> check_invisible_attribute_input_types(dsl, resource, visible)
        else
          warnings
        end
      end)
      |> then(fn warnings ->
        if is_list(explicit_relationships) do
          included_rels = MapSet.new(explicit_relationships)

          warnings
          |> check_excluded_relationship(
            dsl,
            resource,
            included_rels,
            :paginate_relationship_with
          )
          |> check_excluded_relationship(dsl, resource, included_rels, :filterable_fields)
          |> check_excluded_relationship(dsl, resource, included_rels, :field_names)
          |> check_excluded_relationship(dsl, resource, included_rels, :nullable_fields)
        else
          warnings
        end
      end)

    case warnings do
      [] -> :ok
      list -> {:warn, list}
    end
  end

  defp validate_show_hide_contradiction!(_resource, show_fields, hide_fields)
       when is_nil(show_fields) or is_nil(hide_fields),
       do: :ok

  defp validate_show_hide_contradiction!(resource, show_fields, hide_fields) do
    overlap =
      MapSet.intersection(MapSet.new(show_fields), MapSet.new(hide_fields))
      |> MapSet.to_list()
      |> Enum.sort()

    unless Enum.empty?(overlap) do
      raise Spark.Error.DslError,
        module: resource,
        path: [:graphql],
        message: """
        Fields cannot appear in both `show_fields` and `hide_fields`.

        Conflicting fields: #{inspect(overlap)}
        """
    end
  end

  defp compute_visible_fields(dsl, show_fields, hide_fields) do
    base =
      if show_fields do
        MapSet.new(show_fields)
      else
        dsl |> Ash.Resource.Info.public_fields() |> MapSet.new(& &1.name)
      end

    hidden = MapSet.new(hide_fields || [])
    MapSet.difference(base, hidden)
  end

  defp check_invisible_fields(warnings, dsl, resource, visible, option, option_name) do
    value = get_option(dsl, option)

    if is_list(value) do
      field_names = extract_field_names(value)

      Enum.reduce(field_names, warnings, fn field, acc ->
        if MapSet.member?(visible, field) do
          acc
        else
          [invisible_field_warning(resource, field, option_name) | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_invisible_field_names(warnings, dsl, resource, visible) do
    field_names = AshGraphql.Resource.Info.field_names(dsl)

    if is_list(field_names) and field_names != [] do
      Enum.reduce(field_names, warnings, fn {field, _renamed}, acc ->
        if MapSet.member?(visible, field) do
          acc
        else
          [invisible_field_warning(resource, field, "field_names") | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_invisible_relationships(warnings, dsl, resource, visible) do
    # relationships option defaults to nil (meaning all), only check when explicitly set
    relationships = Spark.Dsl.Extension.get_opt(dsl, [:graphql], :relationships, nil)

    if is_list(relationships) do
      Enum.reduce(relationships, warnings, fn rel, acc ->
        if MapSet.member?(visible, rel) do
          acc
        else
          [invisible_field_warning(resource, rel, "relationships") | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_invisible_paginate_relationship_with(warnings, dsl, resource, visible) do
    paginate_with = AshGraphql.Resource.Info.paginate_relationship_with(dsl)

    if is_list(paginate_with) and paginate_with != [] do
      Enum.reduce(paginate_with, warnings, fn {rel, _strategy}, acc ->
        if MapSet.member?(visible, rel) do
          acc
        else
          [invisible_field_warning(resource, rel, "paginate_relationship_with") | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_invisible_attribute_input_types(warnings, dsl, resource, visible) do
    input_types = AshGraphql.Resource.Info.attribute_input_types(dsl)

    if is_list(input_types) and input_types != [] do
      # Only check keys that are actual public attributes. Non-attribute keys
      # (e.g. relationships) are caught by VerifyFieldReferences as invalid.
      attribute_names =
        dsl |> Ash.Resource.Info.public_attributes() |> MapSet.new(& &1.name)

      Enum.reduce(input_types, warnings, fn {attr, _type}, acc ->
        if not MapSet.member?(attribute_names, attr) or MapSet.member?(visible, attr) do
          acc
        else
          [invisible_field_warning(resource, attr, "attribute_input_types") | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_excluded_relationship(
         warnings,
         dsl,
         resource,
         included_rels,
         :paginate_relationship_with
       ) do
    paginate_with = AshGraphql.Resource.Info.paginate_relationship_with(dsl)

    if is_list(paginate_with) and paginate_with != [] do
      Enum.reduce(paginate_with, warnings, fn {rel, _strategy}, acc ->
        if MapSet.member?(included_rels, rel) do
          acc
        else
          [excluded_relationship_warning(resource, rel, "paginate_relationship_with") | acc]
        end
      end)
    else
      warnings
    end
  end

  defp check_excluded_relationship(warnings, dsl, resource, included_rels, option) do
    relationship_names =
      dsl
      |> Ash.Resource.Info.public_relationships()
      |> MapSet.new(& &1.name)

    values = get_relationship_option(dsl, option)

    if is_list(values) and values != [] do
      values
      |> extract_field_names()
      |> Enum.filter(&MapSet.member?(relationship_names, &1))
      |> Enum.reduce(warnings, fn rel, acc ->
        if MapSet.member?(included_rels, rel) do
          acc
        else
          [excluded_relationship_warning(resource, rel, to_string(option)) | acc]
        end
      end)
    else
      warnings
    end
  end

  defp excluded_relationship_warning(resource, field, option_name) do
    "Relationship `#{inspect(field)}` in `#{option_name}` is not included in `relationships` " <>
      "and will have no effect in #{inspect(resource)}."
  end

  defp get_relationship_option(dsl, :filterable_fields),
    do: AshGraphql.Resource.Info.filterable_fields(dsl)

  defp get_relationship_option(dsl, :field_names),
    do: AshGraphql.Resource.Info.field_names(dsl)

  defp get_relationship_option(dsl, :nullable_fields),
    do: AshGraphql.Resource.Info.nullable_fields(dsl)

  defp extract_field_names(fields) do
    Enum.map(fields, fn
      field when is_atom(field) -> field
      {field, _value} when is_atom(field) -> field
    end)
  end

  defp invisible_field_warning(resource, field, option_name) do
    "Field `#{inspect(field)}` in `#{option_name}` is not visible " <>
      "(it is hidden or not in show_fields) and will have no effect in #{inspect(resource)}."
  end

  defp get_option(dsl, :sortable_fields), do: AshGraphql.Resource.Info.sortable_fields(dsl)
  defp get_option(dsl, :filterable_fields), do: AshGraphql.Resource.Info.filterable_fields(dsl)
  defp get_option(dsl, :nullable_fields), do: AshGraphql.Resource.Info.nullable_fields(dsl)
end
