# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyFieldReferences do
  # Validates that field names referenced in graphql DSL options actually exist on the resource.
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    resource = Transformer.get_persisted(dsl, :module)

    attribute_names = dsl |> Ash.Resource.Info.public_attributes() |> MapSet.new(& &1.name)
    relationship_names = dsl |> Ash.Resource.Info.public_relationships() |> MapSet.new(& &1.name)
    calculation_names = dsl |> Ash.Resource.Info.public_calculations() |> MapSet.new(& &1.name)
    aggregate_names = dsl |> Ash.Resource.Info.public_aggregates() |> MapSet.new(& &1.name)

    all_fields =
      attribute_names
      |> MapSet.union(relationship_names)
      |> MapSet.union(calculation_names)
      |> MapSet.union(aggregate_names)

    non_relationship_fields =
      attribute_names
      |> MapSet.union(calculation_names)
      |> MapSet.union(aggregate_names)

    all_fields_desc = "attribute, relationship, calculation, or aggregate"

    validate_option(dsl, resource, :show_fields, all_fields, all_fields_desc)
    validate_option(dsl, resource, :hide_fields, all_fields, all_fields_desc)
    validate_option(dsl, resource, :field_names, all_fields, all_fields_desc)
    validate_option(dsl, resource, :nullable_fields, all_fields, all_fields_desc)
    validate_option(dsl, resource, :filterable_fields, all_fields, all_fields_desc)

    validate_option(
      dsl,
      resource,
      :sortable_fields,
      non_relationship_fields,
      "attribute, calculation, or aggregate"
    )

    validate_option(dsl, resource, :relationships, relationship_names, "relationship")
    validate_option(dsl, resource, :attribute_input_types, attribute_names, "attribute")

    :ok
  end

  defp validate_option(dsl, resource, option, valid_fields, field_type_desc) do
    value = get_option(dsl, option)

    if is_list(value) do
      Enum.each(value, fn
        field when is_atom(field) ->
          validate_field_exists(resource, option, field, valid_fields, field_type_desc)

        {field, _value} when is_atom(field) ->
          validate_field_exists(resource, option, field, valid_fields, field_type_desc)

        _ ->
          :ok
      end)
    end
  end

  defp validate_field_exists(resource, option, field, valid_fields, field_type_desc) do
    if not MapSet.member?(valid_fields, field) do
      available = valid_fields |> MapSet.to_list() |> Enum.sort()

      raise Spark.Error.DslError,
        module: resource,
        path: [:graphql, option],
        message: """
        Unknown #{field_type_desc} `#{inspect(field)}` in `#{option}`.

        Available: #{inspect(available)}
        """
    end
  end

  defp get_option(dsl, :show_fields), do: AshGraphql.Resource.Info.show_fields(dsl)
  defp get_option(dsl, :hide_fields), do: AshGraphql.Resource.Info.hide_fields(dsl)
  defp get_option(dsl, :field_names), do: AshGraphql.Resource.Info.field_names(dsl)
  defp get_option(dsl, :nullable_fields), do: AshGraphql.Resource.Info.nullable_fields(dsl)
  defp get_option(dsl, :sortable_fields), do: AshGraphql.Resource.Info.sortable_fields(dsl)
  defp get_option(dsl, :filterable_fields), do: AshGraphql.Resource.Info.filterable_fields(dsl)

  defp get_option(dsl, :attribute_input_types),
    do: AshGraphql.Resource.Info.attribute_input_types(dsl)

  # relationships/1 in Info falls back to all public relationships when nil,
  # so we read the raw option to only validate when explicitly set by the user.
  defp get_option(dsl, :relationships) do
    Spark.Dsl.Extension.get_opt(dsl, [:graphql], :relationships, nil)
  end
end
