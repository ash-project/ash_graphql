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
      valid_operator_names = valid_operator_names()

      Enum.each(filterable_fields, fn
        field when is_atom(field) ->
          :ok

        {field, ops} when is_atom(field) and is_list(ops) ->
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

  defp valid_operator_names do
    Ash.Filter.builtin_operators()
    |> Enum.filter(& &1.predicate?())
    |> Enum.map(& &1.name())
  end
end
