defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false
  def resolve(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :get, action}
      ) do
    opts =
      if AshGraphql.Api.authorize?(api) do
        [actor: Map.get(context, :actor), action: action]
      else
        [action: action]
      end

    opts = Keyword.put(opts, :load, load_nested(resource, resolution.definition.selections))

    result = api.get(resource, id, opts)

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: %{limit: limit, offset: offset} = args, context: context} = resolution,
        {api, resource, :list, action}
      ) do
    opts =
      if AshGraphql.Api.authorize?(api) do
        [actor: Map.get(context, :actor), action: action]
      else
        [action: action]
      end

    selections =
      case Enum.find(resolution.definition.selections, &(&1.schema_node.identifier == :results)) do
        nil ->
          []

        field ->
          field.selections
      end

    query =
      resource
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)
      |> Ash.Query.load(load_nested(resource, selections))

    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          case Jason.decode(filter) do
            {:ok, decoded} ->
              Ash.Query.filter(query, to_snake_case(decoded))

            {:error, error} ->
              raise "Error parsing filter: #{inspect(error)}"
          end

        _ ->
          query
      end

    result =
      query
      |> api.read(opts)
      |> case do
        {:ok, results} ->
          {:ok, %{results: results, count: Enum.count(results)}}

        error ->
          error
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{input: input}, context: context} = resolution,
        {api, resource, :create, action}
      ) do
    {attributes, relationships} = split_attrs_and_rels(input, resource)

    selections =
      case Enum.find(resolution.definition.selections, &(&1.schema_node.identifier == :result)) do
        nil ->
          []

        field ->
          field.selections
      end

    load = load_nested(resource, selections)

    changeset = Ash.Changeset.new(resource, attributes)

    changeset_with_relationships =
      Enum.reduce(relationships, changeset, fn {relationship, replacement}, changeset ->
        Ash.Changeset.replace_relationship(changeset, relationship, replacement)
      end)

    opts =
      if AshGraphql.Api.authorize?(api) do
        [actor: Map.get(context, :actor), action: action]
      else
        [action: action]
      end

    result =
      with {:ok, value} <- api.create(changeset_with_relationships, opts),
           {:ok, value} <- api.load(value, load) do
        {:ok, %{result: value, errors: []}}
      else
        {:error, error} ->
          {:ok, %{result: nil, errors: to_errors(error)}}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{id: id, input: input}, context: context} = resolution,
        {api, resource, :update, action}
      ) do
    case api.get(resource, id) do
      nil ->
        {:ok, %{result: nil, errors: [to_errors("not found")]}}

      initial ->
        {attributes, relationships} = split_attrs_and_rels(input, resource)
        changeset = Ash.Changeset.new(initial, attributes)

        changeset_with_relationships =
          Enum.reduce(relationships, changeset, fn {relationship, replacement}, changeset ->
            Ash.Changeset.replace_relationship(changeset, relationship, replacement)
          end)

        opts =
          if AshGraphql.Api.authorize?(api) do
            [actor: Map.get(context, :actor), action: action]
          else
            [action: action]
          end

        selections =
          case Enum.find(
                 resolution.definition.selections,
                 &(&1.schema_node.identifier == :result)
               ) do
            nil ->
              []

            field ->
              field.selections
          end

        load = load_nested(resource, selections)

        result =
          with {:ok, value} <- api.update(changeset_with_relationships, opts),
               {:ok, value} <- api.load(value, load) do
            {:ok, %{result: value, errors: []}}
          else
            {:error, error} ->
              {:ok, %{result: nil, errors: List.wrap(error)}}
          end

        Absinthe.Resolution.put_result(resolution, to_resolution(result))
    end
  end

  def mutate(%{arguments: %{id: id}, context: context} = resolution, {api, resource, action}) do
    case api.get(resource, id) do
      nil ->
        {:ok, %{result: nil, errors: [to_errors("not found")]}}

      initial ->
        opts =
          if AshGraphql.Api.authorize?(api) do
            [actor: Map.get(context, :actor), action: action]
          else
            [action: action]
          end

        result =
          case api.destroy(initial, opts) do
            :ok -> {:ok, %{result: initial, errors: []}}
            {:error, error} -> {:ok, %{result: nil, errors: to_errors(error)}}
          end

        Absinthe.Resolution.put_result(resolution, to_resolution(result))
    end
  end

  defp split_attrs_and_rels(input, resource) do
    Enum.reduce(input, {%{}, %{}}, fn {key, value}, {attrs, rels} ->
      if Ash.Resource.attribute(resource, key) do
        {Map.put(attrs, key, value), rels}
      else
        {attrs, Map.put(rels, key, value)}
      end
    end)
  end

  defp to_errors(errors) do
    errors
    |> List.wrap()
    |> Enum.map(fn error ->
      cond do
        is_binary(error) ->
          %{message: error}

        Exception.exception?(error) ->
          %{
            message: Exception.message(error)
          }

        true ->
          %{message: "something went wrong"}
      end
    end)
  end

  def resolve_assoc(%{source: parent} = resolution, {:one, name}) do
    Absinthe.Resolution.put_result(resolution, {:ok, Map.get(parent, name)})
  end

  def resolve_assoc(%{source: parent} = resolution, {:many, name}) do
    values = Map.get(parent, name)
    paginator = %{results: values, count: Enum.count(values)}

    Absinthe.Resolution.put_result(resolution, {:ok, paginator})
  end

  defp load_nested(resource, fields) do
    Enum.map(fields, fn field ->
      relationship = Ash.Resource.relationship(resource, field.schema_node.identifier)

      cond do
        !relationship ->
          field.schema_node.identifier

        relationship.cardinality == :many ->
          trimmed_nested = nested_selections_with_pagination(field)

          nested_loads = load_nested(relationship.destination, trimmed_nested)

          query = Ash.Query.load(relationship.destination, nested_loads)

          query = apply_load_arguments(field, query)

          {field.schema_node.identifier, query}

        true ->
          nested_loads = load_nested(relationship.destination, field.selections)

          query = Ash.Query.load(relationship.destination, nested_loads)
          {field.schema_node.identifier, query}
      end
    end)
  end

  defp apply_load_arguments(field, query) do
    Enum.reduce(field.arguments, query, fn
      %{name: "limit", value: value}, query ->
        Ash.Query.limit(query, value)

      %{name: "offset", value: value}, query ->
        Ash.Query.offset(query, value)

      %{name: "filter", value: value}, query ->
        decode_and_filter(query, value)
    end)
  end

  defp nested_selections_with_pagination(field) do
    Enum.flat_map(field.selections, fn nested ->
      if nested.schema_node.identifier == :results do
        nested.selections
      else
        []
      end
    end)
  end

  defp decode_and_filter(query, value) do
    case Jason.decode(value) do
      {:ok, decoded} ->
        Ash.Query.filter(query, to_snake_case(decoded))

      {:error, error} ->
        raise "Error parsing filter: #{inspect(error)}"
    end
  end

  defp to_snake_case(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {Macro.underscore(key), to_snake_case(value)}
    end)
  end

  defp to_snake_case(list) when is_list(list) do
    Enum.map(list, &to_snake_case/1)
  end

  defp to_snake_case(other), do: other

  defp to_resolution({:ok, value}), do: {:ok, value}

  defp to_resolution({:error, error}),
    do: {:error, error |> List.wrap() |> Enum.map(&Exception.message(&1))}
end
