# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyArgumentInputTypes do
  # Ensures that argument_input_types configuration is properly formatted
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    resource = Transformer.get_persisted(dsl, :module)
    argument_input_types = AshGraphql.Resource.Info.argument_input_types(dsl)

    if argument_input_types && argument_input_types != [] do
      actions = Ash.Resource.Info.actions(dsl)
      action_names = MapSet.new(actions, & &1.name)

      Enum.each(argument_input_types, fn {key, value} ->
        cond do
          not is_atom(key) ->
            raise Spark.Error.DslError,
              module: resource,
              path: [:graphql, :argument_input_types],
              message: """
              Invalid argument_input_types configuration. Keys must be action names (atoms).

              Found: #{inspect(key)}

              Expected format:
              argument_input_types action_name: [argument_name: :type, ...]
              """

          not MapSet.member?(action_names, key) ->
            available_actions = actions |> Enum.map(& &1.name) |> Enum.sort()

            raise Spark.Error.DslError,
              module: resource,
              path: [:graphql, :argument_input_types],
              message: """
              Invalid argument_input_types configuration. Action #{inspect(key)} does not exist on #{inspect(resource)}.

              Available actions: #{inspect(available_actions)}

              Expected format:
              argument_input_types action_name: [argument_name: :type, ...]
              """

          not is_list(value) or not Keyword.keyword?(value) ->
            raise Spark.Error.DslError,
              module: resource,
              path: [:graphql, :argument_input_types],
              message: """
              Invalid argument_input_types configuration for action #{inspect(key)}.

              Found: #{inspect(value)}

              Expected a keyword list of argument names to types, like:
              argument_input_types #{key}: [argument_name: :string, another_arg: :integer]

              If you meant to configure a single argument across all actions, you need to specify which action:
              argument_input_types some_action_name: [#{key}: #{inspect(value)}]
              """

          true ->
            :ok
        end
      end)
    end

    :ok
  end
end
