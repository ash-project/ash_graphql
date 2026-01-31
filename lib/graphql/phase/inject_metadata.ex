# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Phase.InjectMetadata do
  @moduledoc false

  use Absinthe.Phase

  require Logger

  def run(blueprint, options) do
    schema = Keyword.fetch!(options, :schema)
    response_metadata_config = schema.response_metadata()

    if response_metadata_config do
      blueprint = inject_metadata(blueprint, response_metadata_config)
      {:ok, blueprint}
    else
      {:ok, blueprint}
    end
  end

  defp inject_metadata(blueprint, response_metadata_config) do
    acc = blueprint.execution.acc[:ash_graphql] || %{}
    start_time = acc[:start_time]
    end_time = acc[:end_time]

    duration_ms =
      if start_time && end_time do
        System.convert_time_unit(end_time - start_time, :native, :millisecond)
      else
        if is_nil(start_time) do
          Logger.warning(
            "AshGraphql response_metadata: start_time not found. " <>
              "Ensure AshGraphql.Plugin.ResponseMetadata is included in your schema's plugins/0 function."
          )
        end

        nil
      end

    complexity = calculate_complexity(blueprint)

    operation_name = get_operation_name(blueprint)
    operation_type = get_operation_type(blueprint)

    info = %{
      complexity: complexity,
      duration_ms: duration_ms,
      operation_name: operation_name,
      operation_type: operation_type
    }

    metadata = build_metadata(response_metadata_config, info)

    if is_map(metadata) && map_size(metadata) > 0 do
      update_in(blueprint.result, fn result ->
        result = result || %{}
        extensions = Map.get(result, :extensions, %{})
        existing_ash = Map.get(extensions, :ash, %{})
        merged_ash = Map.merge(existing_ash, metadata)
        extensions = Map.put(extensions, :ash, merged_ash)
        Map.put(result, :extensions, extensions)
      end)
    else
      blueprint
    end
  end

  defp build_metadata(true, info) do
    AshGraphql.DefaultMetadataHandler.build_metadata(info)
  end

  defp build_metadata({module, function, args}, info)
       when is_atom(module) and is_atom(function) and is_list(args) do
    result = apply(module, function, [info | args])

    case result do
      map when is_map(map) ->
        map

      nil ->
        nil

      other ->
        Logger.warning(
          "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
            "returned #{inspect(other)}, expected a map or nil. Metadata will not be included."
        )

        nil
    end
  rescue
    e ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "raised: #{Exception.format(:error, e, __STACKTRACE__)}. Metadata will not be included."
      )

      nil
  catch
    :throw, value ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "threw: #{inspect(value)}. Metadata will not be included."
      )

      nil

    :exit, reason ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "exited: #{inspect(reason)}. Metadata will not be included."
      )

      nil
  end

  defp build_metadata(false, _info), do: nil
  defp build_metadata(nil, _info), do: nil

  defp build_metadata(invalid_config, _info) do
    Logger.warning(
      "AshGraphql response_metadata received invalid configuration: #{inspect(invalid_config)}. " <>
        "Expected `true`, `false`, or `{Module, :function, args}` tuple. Metadata will not be included."
    )

    nil
  end

  defp calculate_complexity(blueprint) do
    case blueprint.execution.result do
      %{emitter: emitter} when not is_nil(emitter) ->
        sum_complexity(emitter)

      _ ->
        nil
    end
  end

  defp sum_complexity(%Absinthe.Blueprint.Document.Field{complexity: nil}), do: nil

  defp sum_complexity(%Absinthe.Blueprint.Document.Field{} = field) do
    own_complexity = field.complexity || 0

    children_complexity =
      field.selections
      |> Enum.map(&sum_complexity/1)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> 0
        list -> Enum.sum(list)
      end

    own_complexity + children_complexity
  end

  defp sum_complexity(%{selections: selections}) when is_list(selections) do
    complexities =
      selections
      |> Enum.map(&sum_complexity/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(complexities) do
      nil
    else
      Enum.sum(complexities)
    end
  end

  defp sum_complexity(_), do: nil

  defp get_operation_name(blueprint) do
    case blueprint.execution.result do
      %{emitter: %{name: name}} when is_binary(name) and name != "" -> name
      _ -> nil
    end
  end

  defp get_operation_type(blueprint) do
    case blueprint.execution.result do
      %{emitter: %{type: type}} -> type
      _ -> nil
    end
  end
end
