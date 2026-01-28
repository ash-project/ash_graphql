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
        path = build_error_path(error, error_map, graphql_path)

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
  defp build_error_path(error, error_map, graphql_path) do
    # Start with GraphQL input path(e.g., ["input", "override"])
    base_path =
      case graphql_path do
        nil -> []
        path when is_list(path) -> path
        _ -> []
      end

      #  Add Ash.Error.path if available
      ash_path =
        if function_exported?(Ash.Error, :path, 1) do
          try do
            Ash.Error.path(error)
          rescue
            _ -> nil
          catch
            _ -> nil
          end
        else
          nil
        end

      path_from_ash =
        case ash_path do
          nil -> []
          path when is_list(path) -> path
          _ -> []
        end

      # Get field name from error map and convert to camelCase
      field_name =
        case Map.get(error_map, :fields) do
          [field | _] when is_atom(field) -> to_camel_case(field)
          [field | _] when is_binary(field) -> to_camel_case(field)
          _ -> nil
        end

      # Combine paths: GraphQL path + Ash path + field name
      result_path =
        base_path
        |> Enum.concat(path_from_ash)
        |> then(fn path ->
          if field_name, do: path ++ [field_name], else: path
        end)

      # Return nil if path is empty (for backward compatibility)
      if result_path == [], do: nil, else: result_path
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
