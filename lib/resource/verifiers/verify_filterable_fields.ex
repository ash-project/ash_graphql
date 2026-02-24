# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyFilterableFields do
  # Validates the format of filterable_fields, supporting both bare atoms and
  # keyword tuples with operator allowlists (e.g. `[:name, id: [:eq, :in]]`).
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    filterable_fields = AshGraphql.Resource.Info.filterable_fields(dsl)

    if is_nil(filterable_fields) do
      :ok
    else
      resource = Transformer.get_persisted(dsl, :module)

      unless is_list(filterable_fields) do
        raise Spark.Error.DslError,
          module: resource,
          message: """
          Invalid value for `filterable_fields`: #{inspect(filterable_fields)}.

          The `filterable_fields` option must be a list of field names or keyword entries,
          for example: `[:name, id: [:eq, :in]]`.
          """
      end

      valid_operator_names = valid_operator_names(dsl)

      Enum.each(filterable_fields, fn
        field when is_atom(field) ->
          :ok

        {field, ops} when is_atom(field) and is_list(ops) ->
          if Enum.empty?(ops) do
            raise Spark.Error.DslError,
              module: resource,
              message: """
              Empty operator allowlist for field `#{inspect(field)}` in `filterable_fields`.

              Provide at least one valid operator (e.g. `#{inspect(field)}: [:eq]`), or
              list the field as a bare atom to allow all default operators (e.g. `#{inspect(field)}`).
              """
          else
            Enum.each(ops, fn op ->
              unless op in valid_operator_names do
                raise Spark.Error.DslError,
                  module: resource,
                  message: """
                  Invalid operator `#{inspect(op)}` for field `#{inspect(field)}` in `filterable_fields`.

                  Valid operator names are: #{Enum.map_join(valid_operator_names, ", ", &inspect/1)}
                  """
              end
            end)
          end

        other ->
          raise Spark.Error.DslError,
            module: resource,
            message: """
            Invalid entry `#{inspect(other)}` in `filterable_fields`.

            Each entry must be either a bare atom (e.g. `:name`) or a keyword tuple
            with a list of operator names (e.g. `id: [:eq, :in]`).
            """
      end)

      :ok
    end
  end

  defp valid_operator_names(dsl) do
    resource = Transformer.get_persisted(dsl, :module)

    builtin =
      Ash.Filter.builtin_operators()
      |> Enum.filter(& &1.predicate?())
      |> Enum.map(& &1.name())

    data_layer_functions =
      try do
        Ash.DataLayer.functions(resource)
        |> Enum.filter(& &1.predicate?())
        |> Enum.map(& &1.name())
      rescue
        _ -> []
      end

    Enum.uniq(builtin ++ data_layer_functions)
  end
end
