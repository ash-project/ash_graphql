# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Errors do
  @moduledoc """
  Utilities for working with errors in custom resolvers.
  """
  require Logger

  @doc """
  Transform an error or list of errors into the response for graphql.
  """
  def to_errors(errors, context, domain, resource, action) do
    to_errors(errors, context, domain, resource, action, nil)
  end

  @doc """
  Transform an error or list of errors into the response for graphql.

  Accepts an optional `graphql_path` parameter which should be the GraphQL input path
  (e.g., `["input", "override"]`) from the resolution.
  """
  def to_errors(errors, context, domain, resource, action, graphql_path) do
    errors
    |> AshGraphql.Graphql.Resolver.unwrap_errors()
    |> Enum.map(fn error ->
      if AshGraphql.Error.impl_for(error) do
        error_map = AshGraphql.Error.to_error(error)
        context = Map.put(context, :action, action)

        # Build path from GraphQL input path, Ash.Error.path, and field name
        path = build_error_path(error, error_map, graphql_path, resource, action)

        error_with_path = Map.put(error_map, :path, path)

        resource_handled_error =
          case AshGraphql.Resource.Info.error_handler(resource) do
            nil ->
              error_with_path

            {m, f, a} ->
              handled = apply(m, f, [error_with_path, context | a])
              # Ensure path is preserved after resource handler
              Map.put(handled, :path, path)
          end

        case AshGraphql.Domain.Info.error_handler(domain) do
          nil ->
            resource_handled_error

          {m, f, a} ->
            handled = apply(m, f, [resource_handled_error, context | a])
            # Ensure path is preserved after domain handler
            Map.put(handled, :path, path)
        end
      else
        uuid = Ash.UUID.generate()

        if is_exception(error) do
          case error do
            %{stacktrace: %{stacktrace: stacktrace}} ->
              Logger.warning(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
              )

            error ->
              Logger.warning(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error)}"
              )
          end
        else
          Logger.warning(
            "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{inspect(error)}"
          )
        end

        %{
          message: "something went wrong. Unique error id: `#{uuid}`"
        }
      end
    end)
  end

  # Builds the error path by combining the GraphQL input path, Ash.Error.path, and field name
  defp build_error_path(error, error_map, graphql_path, resource, action) do
    # Start with GraphQL input path(e.g., ["input", "override"])
    base_path =
      case graphql_path do
        nil -> []
        path when is_list(path) -> path
        _ -> []
      end

      action_struct = resolve_action_struct(resource, action)

      # Add path from the Ash error if present.
      #
      # NOTE: `Ash.Error.set_path/2` stores the path on the error itself (typically in `:path`),
      # and there isn't a stable `Ash.Error.path/1` function across versions.
      ash_path = Map.get(error, :path)

      path_from_ash =
        case ash_path do
          nil -> []
          path when is_list(path) -> path
          _ -> []
        end

      mapped_base_path =
        base_path
        |> Enum.map(&resolve_graphql_path_segment(&1, resource, action_struct))
        |> Enum.reject(&is_nil/1)

      mapped_path_from_ash =
        path_from_ash
        |> Enum.map(&resolve_graphql_path_segment(&1, resource, action_struct))
        |> Enum.reject(&is_nil/1)

      # Get field name from error map and convert to camelCase.
      #
      # IMPORTANT: the GraphQL name may not be the camelCased Ash field name.
      # We consult the resource's configured `field_names` and the action's `argument_names`
      # mappings (if available) to get the actual GraphQL name.
      field_name =
        case Map.get(error_map, :fields) do
          [field | _] when is_atom(field) ->
            field
            |> resolve_graphql_field_name(resource, action_struct)
            |> to_camel_case()

          [field | _] when is_binary(field) ->
            field
            |> resolve_graphql_field_name(resource, action_struct)
            |> to_camel_case()

          _ -> nil
        end

      # Combine paths: GraphQL path + Ash path + field name
      result_path =
        mapped_base_path
        |> Enum.concat(mapped_path_from_ash)
        |> then(fn path ->
          if field_name, do: path ++ [field_name], else: path
        end)

      # Return nil if path is empty (for backward compatibility)
      if result_path == [], do: nil, else: result_path
  end

  defp resolve_action_struct(resource, action) do
    cond do
      is_map(action) && Map.has_key?(action, :name) ->
        action

      is_atom(action) && is_atom(resource) ->
        # Only attempt lookup if we have a real resource module
        try do
          Ash.Resource.Info.action(resource, action)
        rescue
          _ -> nil
        end

      true ->
        nil
    end
  end

  # Resolve and format ONE segment of an Ash path into the GraphQL field name for that segment.
  # This is where we "check what the field is" (argument vs attribute/relationship/calculation/aggregate)
  # and use the correct DSL mapping.
  defp resolve_graphql_path_segment(segment, resource, action) do
    # Support integer segments (e.g. list indexes) by stringifying them.
    cond do
      is_integer(segment) ->
        Integer.to_string(segment)

      is_atom(segment) ->
        segment
        |> resolve_graphql_field_name(resource, action)
        |> to_camel_case()

      is_binary(segment) ->
        # Avoid creating atoms from arbitrary strings.
        segment_atom =
          try do
            String.to_existing_atom(segment)
          rescue
            _ -> nil
          end

        if segment_atom do
          segment_atom
          |> resolve_graphql_field_name(resource, action)
          |> to_camel_case()
        else
          # If we can't safely treat it as an atom key, just camelCase the string.
          to_camel_case(segment)
        end

      true ->
        nil
    end
  end

  defp resolve_graphql_argument_name(argument, resource, action) do
    if argument && resource && action && Map.has_key?(action, :name) do
      resource
      |> AshGraphql.Resource.Info.argument_names()
      |> then(fn argument_names -> argument_names[action.name] end)
      |> case do
        nil -> nil
        argument_names -> argument_names[argument]
      end
    end
  end

  defp resolve_graphql_field_name(field, resource, action) do
    field_atom =
      case field do
        field when is_atom(field) ->
          field

        field when is_binary(field) ->
          try do
            String.to_existing_atom(field)
          rescue
            _ -> nil
          end
      end

    # Prefer action argument name mappings, if any.
    # Then fall back to field name mappings.
    argument_name_override = resolve_graphql_argument_name(field_atom, resource, action)

    field_name_override =
      if resource && field_atom do
        AshGraphql.Resource.Info.field_names(resource)[field_atom]
      end

    argument_name_override || field_name_override || field_atom || field
  end

  # Converts snake_case to camelCase
  defp to_camel_case(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> to_camel_case()
  end

  defp to_camel_case(string) when is_binary(string) do
    camelized = Macro.camelize(string)

    # Lowercase the first character if it's an uppercase letter
    case camelized do
      <<char::utf8, rest::binary>> when char >= ?A and char <= ?Z ->
        <<char + 32::utf8, rest::binary>>
      _ ->
        camelized
    end
  end

  defp to_camel_case(other), do: to_string(other)
end
