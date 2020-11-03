defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Ash.Query

  def resolve(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :get, action}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    result =
      resource
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.filter(id == ^id)
      |> api.read_one(opts)

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: %{limit: limit, offset: offset} = args, context: context} = resolution,
        {api, resource, :list, action}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    query =
      resource
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)

    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          case Jason.decode(filter) do
            {:ok, decoded} ->
              Ash.Query.filter(query, ^to_snake_case(decoded))

            {:error, error} ->
              raise "Error parsing filter: #{inspect(error)}"
          end

        _ ->
          query
      end

    result =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
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

    changeset = Ash.Changeset.new(resource, attributes)

    changeset_with_relationships =
      Enum.reduce(relationships, changeset, fn {relationship, replacement}, changeset ->
        Ash.Changeset.replace_relationship(changeset, relationship, replacement)
      end)

    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    result =
      changeset_with_relationships
      |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
      |> api.create(opts)
      |> case do
        {:ok, value} ->
          {:ok, %{result: value, errors: []}}

        {:error, error} ->
          {:ok, %{result: nil, errors: to_errors(error)}}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{id: id, input: input}, context: context} = resolution,
        {api, resource, :update, action}
      ) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.set_tenant(Map.get(context, :tenant))
    |> api.read_one!()
    |> case do
      nil ->
        {:ok, %{result: nil, errors: [to_errors("not found")]}}

      initial ->
        {attributes, relationships} = split_attrs_and_rels(input, resource)
        changeset = Ash.Changeset.new(initial, attributes)

        changeset_with_relationships =
          Enum.reduce(relationships, changeset, fn {relationship, replacement}, changeset ->
            Ash.Changeset.replace_relationship(changeset, relationship, replacement)
          end)

        opts = [
          actor: Map.get(context, :actor),
          authorize?: AshGraphql.Api.authorize?(api),
          action: action
        ]

        result =
          changeset_with_relationships
          |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
          |> api.update(opts)
          |> case do
            {:ok, value} ->
              {:ok, %{result: value, errors: []}}

            {:error, error} ->
              {:ok, %{result: nil, errors: List.wrap(error)}}
          end

        Absinthe.Resolution.put_result(resolution, to_resolution(result))
    end
  end

  def mutate(
        %{arguments: %{id: id}, context: context} = resolution,
        {api, resource, :destroy, action}
      ) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.set_tenant(Map.get(context, :tenant))
    |> api.read_one!()
    |> case do
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
          initial
          |> Ash.Changeset.new()
          |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
          |> api.destroy(opts)
          |> case do
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

  def resolve_assoc(
        %{source: parent, arguments: args, context: %{loader: loader} = context} = resolution,
        {api, relationship}
      ) do
    api_opts = [actor: Map.get(context, :actor), authorize?: AshGraphql.Api.authorize?(api)]

    opts = [
      query: apply_load_arguments(args, Ash.Query.new(relationship.destination)),
      api_opts: api_opts,
      tenant: Map.get(context, :tenant)
    ]

    {batch_key, parent} = {{relationship.name, opts}, parent}

    do_dataloader(resolution, loader, api, batch_key, args, parent)
  end

  defp do_dataloader(
         resolution,
         loader,
         api,
         batch_key,
         _args,
         parent
       ) do
    loader = Dataloader.load(loader, api, batch_key, parent)

    fun = fn loader ->
      {:ok, Dataloader.get(loader, api, batch_key, parent)}
    end

    Absinthe.Resolution.put_result(
      resolution,
      {:middleware, Absinthe.Middleware.Dataloader, {loader, fun}}
    )
  end

  defp apply_load_arguments(arguments, query) do
    Enum.reduce(arguments, query, fn
      {:limit, limit}, query ->
        Ash.Query.limit(query, limit)

      {:offset, offset}, query ->
        Ash.Query.offset(query, offset)

      {:filter, value}, query ->
        decode_and_filter(query, value)
    end)
  end

  defp decode_and_filter(query, value) do
    case Jason.decode(value) do
      {:ok, decoded} ->
        Ash.Query.filter(query, ^to_snake_case(decoded))

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
