# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Phase.InjectMetadata do
  @moduledoc """
  Absinthe phase that injects metadata into response extensions.

  The key under which metadata appears is configured via the `response_metadata` option.
  Automatically added to the pipeline by `AshGraphql.Plugin.ResponseMetadata`
  when `response_metadata` is enabled.
  """

  use Absinthe.Phase

  require Logger

  @doc false
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

    operation = Enum.find(blueprint.operations, & &1.current)

    complexity =
      case operation do
        %{complexity: c} when is_integer(c) -> c
        _ -> nil
      end

    operation_name =
      case operation do
        %{name: name} when not is_nil(name) -> name
        _ -> nil
      end

    operation_type =
      case operation do
        %{type: t} -> t
        _ -> nil
      end

    info = %{
      complexity: complexity,
      duration_ms: duration_ms,
      operation_name: operation_name,
      operation_type: operation_type
    }

    {key, metadata} = build_metadata(response_metadata_config, info)

    if is_map(metadata) && map_size(metadata) > 0 do
      update_in(blueprint.result, fn result ->
        result = result || %{}
        extensions = Map.get(result, :extensions, %{})
        existing = Map.get(extensions, key, %{})
        merged = Map.merge(existing, metadata)
        extensions = Map.put(extensions, key, merged)
        Map.put(result, :extensions, extensions)
      end)
    else
      blueprint
    end
  end

  defp build_metadata(true, _info) do
    Logger.warning(
      "AshGraphql response_metadata is set to `true` but requires a key. " <>
        "Use `response_metadata: :my_extension_key` to specify the extensions key."
    )

    {nil, nil}
  end

  defp build_metadata(key, info) when is_atom(key) do
    {key, AshGraphql.DefaultMetadataHandler.build_metadata(info)}
  end

  defp build_metadata({key, {module, function, args}}, info)
       when is_atom(key) and is_atom(module) and is_atom(function) and is_list(args) do
    result = apply(module, function, [info | args])

    case result do
      map when is_map(map) ->
        {key, map}

      nil ->
        {key, nil}

      other ->
        Logger.warning(
          "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
            "returned #{inspect(other)}, expected a map or nil. Metadata will not be included."
        )

        {key, nil}
    end
  rescue
    e ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "raised: #{Exception.format(:error, e, __STACKTRACE__)}. Metadata will not be included."
      )

      {key, nil}
  catch
    :throw, value ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "threw: #{inspect(value)}. Metadata will not be included."
      )

      {key, nil}

    :exit, reason ->
      Logger.warning(
        "AshGraphql response_metadata handler #{inspect(module)}.#{function}/#{length(args) + 1} " <>
          "exited: #{inspect(reason)}. Metadata will not be included."
      )

      {key, nil}
  end

  defp build_metadata(false, _info), do: {nil, nil}
  defp build_metadata(nil, _info), do: {nil, nil}

  defp build_metadata(invalid_config, _info) do
    Logger.warning(
      "AshGraphql response_metadata received invalid configuration: #{inspect(invalid_config)}. " <>
        "Expected an atom key, `false`, or `{key, {Module, :function, args}}` tuple. Metadata will not be included."
    )

    {nil, nil}
  end
end
