# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Domain.Transformers.ValidateCompatibleNames do
  # Ensures that all field names are valid or remapped to something valid exist
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def after_compile?, do: true

  def transform(dsl) do
    dsl
    |> Transformer.get_entities([:graphql, :queries])
    |> Enum.concat(Transformer.get_entities(dsl, [:graphql, :mutations]))
    |> Enum.each(fn query_or_mutation ->
      argument_names = AshGraphql.Resource.Info.argument_names(query_or_mutation.resource)
      action = Ash.Resource.Info.action(query_or_mutation.resource, query_or_mutation.action)

      Enum.each(action.arguments, fn argument ->
        name = argument_names[action.name][argument.name] || argument.name

        if invalid_name?(name) do
          raise_invalid_argument_name_error(
            query_or_mutation.resource,
            action,
            argument.name,
            name
          )
        end
      end)
    end)

    {:ok, dsl}
  end

  defp invalid_name?(name) do
    Regex.match?(~r/_+\d/, to_string(name))
  end

  defp raise_invalid_argument_name_error(resource, action, argument_name, name) do
    path = [:actions, action.type, action.name, :argument, argument_name]

    raise Spark.Error.DslError,
      module: resource,
      path: path,
      message: """
      Name #{name} is invalid.

      Due to issues in the underlying tooling with camel/snake case conversion of names that
      include underscores immediately preceding integers, a different name must be provided to
      use in the graphql. To do so, add a mapping in your configured argument_names, i.e

          graphql do
            ...

            argument_names #{action.name}: [#{argument_name}: :#{make_name_better(name)}]

            ...
          end


      For more information on the underlying issue, see: https://github.com/absinthe-graphql/absinthe/issues/601
      """
  end

  defp make_name_better(name) do
    name
    |> to_string()
    |> String.replace(~r/_+\d/, fn v ->
      String.trim_leading(v, "_")
    end)
  end
end
