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
              Map.put_new(handled, :path, path)
          end

        case AshGraphql.Domain.Info.error_handler(domain) do
          nil ->
            resource_handled_error

          {m, f, a} ->
            handled = apply(m, f, [resource_handled_error, context | a])
            # Ensure path is preserved after domain handler
            Map.put_new(handled, :path, path)
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

  # Builds the error path by combining GraphQL input path, Ash.Error.path, and field name.
  # Uses type-aware resolution for composite types (union, map, struct, NewType) so nested
  # path segments match the schema expansion.
  defp build_error_path(error, error_map, graphql_path, resource, action) do
    base_path =
      case graphql_path do
        nil -> []
        path when is_list(path) -> path
        _ -> []
      end

    action_struct = resolve_action_struct(resource, action)

    ash_path = Map.get(error, :path)
    path_from_ash =
      case ash_path do
        nil -> []
        path when is_list(path) -> path
        _ -> []
      end

    # Resolve all path segments with type context (handles composite types).
    initial_context = %{resource: resource, action: action_struct, type: nil, constraints: []}
    all_segments = base_path ++ path_from_ash
    {mapped_path, _context} =
      Enum.reduce(all_segments, {[], initial_context}, fn segment, {acc, ctx} ->
        {resolved, next_ctx} = resolve_segment_with_context(segment, ctx)
        acc = if resolved, do: acc ++ [resolved], else: acc
        {acc, next_ctx}
      end)

    # Append field name from error map (resolved with current context).
    field_name =
      case Map.get(error_map, :fields) do
        [field | _] when is_atom(field) or is_binary(field) ->
          resolve_graphql_field_name_with_context(field, resource, action_struct, mapped_path)
          |> to_camel_case()

        _ ->
          nil
      end

    result_path = if field_name, do: mapped_path ++ [field_name], else: mapped_path
    if result_path == [], do: nil, else: result_path
  end

  # Resolves one path segment using type context (for composite types). Returns {resolved_string, next_context}.
  defp resolve_segment_with_context(segment, context) do
    cond do
      is_integer(segment) ->
        # List index: keep context (still inside same composite).
        {Integer.to_string(segment), context}

      context.type == nil ->
        # Top-level: argument or attribute; resolve name and set context from type.
        resolve_top_level_segment(segment, context)

      composite_kind(context.type, context.constraints) == :union ->
        resolve_union_segment(segment, context)

      composite_kind(context.type, context.constraints) == :map_struct ->
        resolve_map_struct_segment(segment, context)

      composite_kind(context.type, context.constraints) == :array ->
        # Segment after array is element type (e.g. index then field); keep segment resolution, context = element type.
        resolve_array_element_segment(segment, context)

      true ->
        # Unknown composite or primitive: resolve name, clear context.
        {resolve_segment_name_only(segment, context), %{context | type: nil, constraints: []}}
    end
  end

  defp resolve_top_level_segment(segment, context) do
    segment_atom = segment_to_atom(segment)
    name = resolve_graphql_field_name(segment_atom, context.resource, context.action)
    name_str = to_camel_case(name || segment)

    type_result =
      if segment_atom do
        find_argument_type(segment_atom, context.action) ||
          find_attribute_type(segment_atom, context.resource)
      end

    {type, constraints} =
      case type_result do
        nil -> {nil, []}
        {arg_type, arg_constraints} when arg_type != nil -> unwrap_type(arg_type, arg_constraints || [])
        _ -> {nil, []}
      end

    next_context = %{context | type: type, constraints: constraints}
    {name_str, next_context}
  end

  defp resolve_union_segment(segment, context) do
    types = context.constraints[:types] || context.constraints["types"] || %{}
    segment_atom = segment_to_atom(segment)
    config =
      cond do
        is_list(types) -> Keyword.get(types, segment_atom)
        is_map(types) -> Map.get(types, segment_atom) || (is_binary(segment) && Map.get(types, segment))
        true -> nil
      end

    if config != nil do
      type = (is_list(config) && Keyword.get(config, :type)) || Map.get(config, :type) || Map.get(config, "type")
      constraints = (is_list(config) && Keyword.get(config, :constraints)) || Map.get(config, :constraints) || Map.get(config, "constraints") || []
      {type, constraints} = unwrap_type(type, constraints)
      # GraphQL union input uses variant key as field name (string).
      name_str = segment_to_graphql_name(segment)
      {name_str, %{context | type: type, constraints: constraints}}
    else
      {resolve_segment_name_only(segment, context), %{context | type: nil, constraints: []}}
    end
  end

  defp resolve_map_struct_segment(segment, context) do
    fields = context.constraints[:fields] || context.constraints["fields"] || []
    segment_atom = segment_to_atom(segment)
    field_config =
      cond do
        is_list(fields) -> Keyword.get(fields, segment_atom)
        is_map(fields) -> Map.get(fields, segment_atom) || (is_binary(segment) && Map.get(fields, segment))
        true -> nil
      end

    if field_config != nil do
      type = (is_list(field_config) && Keyword.get(field_config, :type)) || Map.get(field_config, :type) || Map.get(field_config, "type")
      constraints = (is_list(field_config) && Keyword.get(field_config, :constraints)) || Map.get(field_config, :constraints) || Map.get(field_config, "constraints") || []
      {type, constraints} = unwrap_type(type, constraints)
      name_str = segment_to_graphql_name(segment)
      {name_str, %{context | type: type, constraints: constraints}}
    else
      {resolve_segment_name_only(segment, context), %{context | type: nil, constraints: []}}
    end
  end

  defp resolve_array_element_segment(segment, context) do
    # Context type is {:array, elem_type}; after index we're "in" element.
    elem_type = match?({:array, _}, context.type) && elem(context.type, 2)
    elem_constraints = context.constraints[:items] || context.constraints["items"] || []
    {elem_type, elem_constraints} = unwrap_type(elem_type, elem_constraints)
    inner_context = %{context | type: elem_type, constraints: elem_constraints}
    resolve_segment_with_context(segment, inner_context)
  end

  defp resolve_segment_name_only(segment, context) do
    case segment do
      s when is_atom(s) -> s |> resolve_graphql_field_name(context.resource, context.action) |> to_camel_case()
      s when is_binary(s) ->
        atom = try do
          String.to_existing_atom(s)
        rescue
          _ -> nil
        end
        if atom, do: (resolve_graphql_field_name(atom, context.resource, context.action) || atom) |> to_camel_case(), else: to_camel_case(s)
      _ -> to_string(segment)
    end
  end

  defp segment_to_atom(segment) when is_atom(segment), do: segment
  defp segment_to_atom(segment) when is_binary(segment) do
    try do
      String.to_existing_atom(segment)
    rescue
      _ -> nil
    end
  end
  defp segment_to_atom(_), do: nil

  defp segment_to_graphql_name(segment) when is_atom(segment), do: segment |> Atom.to_string() |> to_camel_case()
  defp segment_to_graphql_name(segment) when is_binary(segment), do: to_camel_case(segment)
  defp segment_to_graphql_name(segment), do: to_string(segment)

  # Returns :union, :map_struct, :array, or nil (primitive / unknown).
  defp composite_kind(type, constraints) do
    {type, constraints} = unwrap_type(type, constraints)
    cond do
      type == nil -> nil
      type == Ash.Type.Union -> :union
      match?({:array, _}, type) -> :array
      type in [:map, Ash.Type.Map, :struct, Ash.Type.Struct] ->
        if (constraints[:fields] || constraints["fields"] || []) != [], do: :map_struct, else: nil
      true ->
        if new_type?(type) do
          subtype = Ash.Type.NewType.subtype_of(type)
          sub_constraints = Ash.Type.NewType.constraints(type, constraints)
          composite_kind(subtype, sub_constraints)
        else
          nil
        end
    end
  end

  defp new_type?(type) do
    Code.ensure_loaded?(Ash.Type.NewType) &&
      function_exported?(Ash.Type.NewType, :new_type?, 1) &&
      Ash.Type.NewType.new_type?(type)
  rescue
    _ -> false
  end

  defp unwrap_type(type, constraints) do
    cond do
      type == nil -> {nil, constraints || []}
      match?({:array, _}, type) ->
        {:array, inner} = type
        {{:array, inner}, constraints || []}
      new_type?(type) ->
        subtype = Ash.Type.NewType.subtype_of(type)
        sub_constraints = Ash.Type.NewType.constraints(type, constraints || [])
        unwrap_type(subtype, sub_constraints)
      true -> {type, constraints || []}
    end
  end

  defp find_argument_type(name, action) when is_atom(name) and not is_nil(action) do
    args = Map.get(action, :arguments) || []
    arg = Enum.find(args, fn a -> Map.get(a, :name) == name end)
    if arg, do: {Map.get(arg, :type), Map.get(arg, :constraints) || []}, else: nil
  end
  defp find_argument_type(_, _), do: nil

  defp find_attribute_type(name, resource) when is_atom(name) and not is_nil(resource) do
    try do
      attrs = Ash.Resource.Info.attributes(resource) || []
      attr = Enum.find(attrs, fn a -> Map.get(a, :name) == name end)
      if attr, do: {Map.get(attr, :type), Map.get(attr, :constraints) || []}, else: nil
    rescue
      _ -> nil
    end
  end
  defp find_attribute_type(_, _), do: nil

  # Resolve field name for error_map[:fields] using same DSL; no context needed for single field.
  defp resolve_graphql_field_name_with_context(field, resource, action, _mapped_path) do
    resolve_graphql_field_name(field, resource, action)
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

  defp resolve_graphql_field_name(nil, _resource, _action), do: nil

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

    # Lowercase the first character if it's uppercase
    case camelized do
      <<char::utf8, rest::binary>> when char >= ?A and char <= ?Z ->
        <<char + 32::utf8, rest::binary>>
      _ ->
        camelized
    end
  end

  defp to_camel_case(other), do: to_string(other)
end
