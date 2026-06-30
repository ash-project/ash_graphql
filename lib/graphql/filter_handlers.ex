# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Graphql.FilterHandlers do
  @moduledoc false

  require Ash.Expr
  import Ash.Expr

  alias AshGraphql.Graphql.Resolver

  require Ash.Query

  @boolean_keys [:and, :or, :not]

  @doc """
  Splits a GraphQL filter into a keyword list suitable for `Ash.Query.filter_input/2`
  and any handler-produced expressions.
  """
  def apply_filter(_resource, nil, _context), do: {:ok, nil, []}

  def apply_filter(resource, filter, context) when is_map(filter) do
    {exprs, remaining} = process_filter(resource, filter, context)

    filter_input =
      case remaining do
        remaining when remaining == %{} -> nil
        rest -> Resolver.massage_filter(resource, rest)
      end

    {:ok, filter_input, exprs}
  end

  def apply_filter(_resource, _filter, _context), do: {:ok, nil, []}

  @doc false
  def apply_filter_to_resource(resource, filter, context) do
    {:ok, filter_input, exprs} = apply_filter(resource, filter, context)

    resource
    |> Ash.Query.new()
    |> apply_filter_parts(filter_input, exprs)
  end

  @doc false
  def apply_filter_to_query(query, filter, context) do
    {:ok, filter_input, exprs} = apply_filter(query.resource, filter, context)
    apply_filter_parts(query, filter_input, exprs)
  end

  @doc false
  def apply_read_one_filter(resource, filter, context) do
    {exprs, remaining} = process_filter(resource, filter, context)

    with {:ok, parsed} <- parse_remaining_filter(resource, remaining) do
      query =
        case parsed do
          nil -> Ash.Query.new(resource)
          parsed -> Ash.Query.do_filter(resource, parsed)
        end

      {:ok, apply_exprs(query, exprs)}
    end
  end

  defp parse_remaining_filter(_resource, remaining) when remaining == %{} do
    {:ok, nil}
  end

  defp parse_remaining_filter(resource, remaining) do
    Ash.Filter.parse_input(resource, remaining)
  end

  @doc """
  Decodes a Relay global ID and returns an Ash expression for the configured field.

  The MFA receives the filter operand value and a context map with `:resource`,
  `:field`, `:operator`, `:handler_args`, `:relay_ids?`, `:actor`, and `:tenant`.
  """
  def relay_id(relay_type, value, context) do
    field = context.field
    operator = context.operator
    resource = context.resource

    case operator do
      :in when is_list(value) ->
        decoded =
          Enum.map(value, &decode_relay_id_value(resource, relay_type, &1))

        if Enum.all?(decoded, &match?({:ok, _}, &1)) do
          list = Enum.map(decoded, fn {:ok, v} -> v end)
          expr(^ref(field) in ^list)
        else
          expr(false)
        end

      :isNil ->
        expr(is_nil(^ref(field)))

      op
      when op in [
             :eq,
             :notEq,
             :lessThan,
             :greaterThan,
             :lessThanOrEqual,
             :greaterThanOrEqual,
             :isDistinctFrom,
             :isNotDistinctFrom
           ] ->
        case decode_relay_id_value(resource, relay_type, value) do
          {:ok, decoded} ->
            comparison_expr(field, operator, decoded)

          _ ->
            expr(false)
        end

      _ ->
        expr(false)
    end
  end

  defp apply_filter_parts(query, nil, []), do: query

  defp apply_filter_parts(query, filter_input, exprs) do
    query
    |> maybe_filter_input(filter_input)
    |> apply_exprs(exprs)
  end

  defp maybe_filter_input(query, nil), do: query
  defp maybe_filter_input(query, filter_input), do: Ash.Query.filter_input(query, filter_input)

  defp apply_exprs(query, []), do: query

  defp apply_exprs(query, exprs) do
    Enum.reduce(exprs, query, fn expression, acc ->
      Ash.Query.do_filter(acc, expression)
    end)
  end

  defp process_filter(resource, filter, context) when is_map(filter) do
    Enum.reduce(filter, {[], %{}}, fn entry, acc ->
      process_filter_entry(resource, entry, context, acc)
    end)
  end

  defp process_filter_entry(resource, {key, value}, context, {exprs, rest}) do
    cond do
      key in @boolean_keys ->
        process_boolean_filter(resource, key, value, context, {exprs, rest})

      not is_nil(Ash.Resource.Info.relationship(resource, key)) ->
        rel = Ash.Resource.Info.relationship(resource, key)
        {sub_exprs, sub_rest} = process_filter(rel.destination, value, context)

        {exprs ++ sub_exprs, Map.put(rest, key, sub_rest)}

      not is_nil(Ash.Resource.Info.calculation(resource, key)) ->
        {exprs, Map.put(rest, key, value)}

      not is_nil(AshGraphql.Resource.Info.filter_handler(resource, key)) ->
        handler = AshGraphql.Resource.Info.filter_handler(resource, key)
        {handler_exprs, _} = apply_handler(resource, key, value, handler, context)
        {exprs ++ handler_exprs, rest}

      true ->
        {exprs, Map.put(rest, key, value)}
    end
  end

  defp process_boolean_filter(resource, :not, [value], context, {exprs, rest}) do
    {sub_exprs, sub_rest} = process_filter(resource, value, context)
    {exprs ++ sub_exprs, Map.put(rest, :not, [sub_rest])}
  end

  defp process_boolean_filter(resource, :not, value, context, acc) when is_map(value) do
    process_boolean_filter(resource, :not, [value], context, acc)
  end

  defp process_boolean_filter(resource, key, values, context, {exprs, rest})
       when key in [:and, :or] and is_list(values) do
    {sub_exprs, sub_rests} =
      Enum.map(values, fn value ->
        process_filter(resource, value, context)
      end)
      |> Enum.unzip()

    sub_rests = Enum.reject(sub_rests, &(&1 == %{}))

    {exprs ++ List.flatten(sub_exprs),
     if sub_rests == [] do
       rest
     else
       Map.put(rest, key, sub_rests)
     end}
  end

  defp apply_handler(resource, field, operator_map, handler, context) when is_map(operator_map) do
    {module, function, extra_args} = handler.handler

    exprs =
      Enum.map(operator_map, fn {operator, value} ->
        handler_context =
          context
          |> Map.put(:resource, resource)
          |> Map.put(:field, field)
          |> Map.put(:operator, operator)
          |> Map.put(:handler_args, extra_args)

        apply(module, function, extra_args ++ [value, handler_context])
      end)

    {exprs, nil}
  end

  defp apply_handler(resource, field, value, handler, context) do
    apply_handler(resource, field, %{eq: value}, handler, context)
  end

  defp decode_relay_id_value(resource, relay_type, id) when is_binary(id) do
    with {:ok, %{type: ^relay_type, id: primary_key}} <- AshGraphql.Resource.decode_relay_id(id),
         {:ok, decoded} <- AshGraphql.Resource.decode_primary_key(resource, primary_key),
         {:ok, value} <- cast_primary_key_value(resource, decoded) do
      {:ok, value}
    else
      _ -> {:error, :invalid}
    end
  end

  defp decode_relay_id_value(_resource, _relay_type, _id), do: {:error, :invalid}

  defp cast_primary_key_value(resource, [{field, value}]) do
    attribute = Ash.Resource.Info.attribute(resource, field)

    case Ash.Type.cast_input(attribute.type, value, attribute.constraints) do
      {:ok, casted} -> {:ok, casted}
      _ -> {:error, :invalid}
    end
  end

  defp cast_primary_key_value(_resource, _), do: {:error, :invalid}

  defp comparison_expr(field, :eq, value), do: expr(^ref(field) == ^value)
  defp comparison_expr(field, :notEq, value), do: expr(^ref(field) != ^value)
  defp comparison_expr(field, :lessThan, value), do: expr(^ref(field) < ^value)
  defp comparison_expr(field, :greaterThan, value), do: expr(^ref(field) > ^value)
  defp comparison_expr(field, :lessThanOrEqual, value), do: expr(^ref(field) <= ^value)
  defp comparison_expr(field, :greaterThanOrEqual, value), do: expr(^ref(field) >= ^value)
  defp comparison_expr(field, :isDistinctFrom, value), do: expr(^ref(field) !== ^value)
  defp comparison_expr(field, :isNotDistinctFrom, value), do: expr(^ref(field) === ^value)
end
