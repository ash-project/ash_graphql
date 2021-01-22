defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Ash.Query

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {api, resource, %{type: :get, action: action, identity: identity}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    filter =
      if identity do
        {:ok,
         resource
         |> Ash.Resource.identities()
         |> Enum.find(&(&1.name == identity))
         |> Map.get(:keys)
         |> Enum.map(fn key ->
           {key, Map.get(arguments, key)}
         end)}
      else
        case AshGraphql.Resource.decode_primary_key(resource, Map.get(arguments, :id) || "") do
          {:ok, value} -> {:ok, [id: value]}
          {:error, error} -> {:error, error}
        end
      end

    result =
      case filter do
        {:ok, filter} ->
          resource
          |> Ash.Query.new()
          |> Ash.Query.set_tenant(Map.get(context, :tenant))
          |> Ash.Query.filter(^filter)
          |> set_query_arguments(action, arguments)
          |> api.read_one(opts)

        {:error, error} ->
          {:error, error}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: args, context: context, definition: %{selections: selections}} = resolution,
        {api, resource, %{type: :list, action: action}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    page_opts =
      args
      |> Map.take([:limit, :offset, :after, :before])
      |> Enum.reject(fn {_, val} -> is_nil(val) end)

    opts =
      case page_opts do
        [] ->
          opts

        page_opts ->
          if Enum.any?(selections, &(&1.name == :count)) do
            page_opts = Keyword.put(page_opts, :count, true)
            Keyword.put(opts, :page, page_opts)
          else
            Keyword.put(opts, :page, page_opts)
          end
      end

    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          Ash.Query.filter(resource, ^filter)

        _ ->
          Ash.Query.new(resource)
      end

    query =
      case Map.fetch(args, :sort) do
        {:ok, sort} ->
          keyword_sort =
            Enum.map(sort, fn %{order: order, field: field} ->
              {field, order}
            end)

          Ash.Query.sort(query, keyword_sort)

        _ ->
          query
      end

    result =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> set_query_arguments(action, args)
      |> api.read(opts)
      |> case do
        {:ok, %{results: results, count: count}} ->
          {:ok, %{results: results, count: count}}

        {:ok, results} ->
          if Ash.Resource.action(resource, action, :read).pagination do
            {:ok, %{results: results, count: Enum.count(results)}}
          else
            {:ok, results}
          end

        error ->
          error
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{input: input}, context: context} = resolution,
        {api, resource, %{type: :create, action: action}}
      ) do
    {attributes, relationships, arguments} = split_attrs_rels_and_args(input, resource)

    changeset = Ash.Changeset.new(resource, attributes)

    changeset_with_relationships = changeset_with_relationships(relationships, changeset)

    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action
    ]

    result =
      changeset_with_relationships
      |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
      |> Ash.Changeset.set_arguments(arguments)
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
        %{arguments: %{input: input} = arguments, context: context} = resolution,
        {api, resource, %{type: :update, action: action, identity: identity}}
      ) do
    filter =
      if identity do
        {:ok,
         resource
         |> Ash.Resource.identities()
         |> Enum.find(&(&1.name == identity))
         |> Map.get(:keys)
         |> Enum.map(fn key ->
           {key, Map.get(arguments, key)}
         end)}
      else
        case AshGraphql.Resource.decode_primary_key(resource, Map.get(arguments, :id) || "") do
          {:ok, value} -> {:ok, [id: value]}
          {:error, error} -> {:error, error}
        end
      end

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> set_query_arguments(action, arguments)
        |> api.read_one!()
        |> case do
          nil ->
            {:ok, %{result: nil, errors: [to_errors("not found")]}}

          initial ->
            {attributes, relationships, arguments} = split_attrs_rels_and_args(input, resource)
            changeset = Ash.Changeset.new(initial, attributes)

            changeset_with_relationships = changeset_with_relationships(relationships, changeset)

            opts = [
              actor: Map.get(context, :actor),
              authorize?: AshGraphql.Api.authorize?(api),
              action: action
            ]

            result =
              changeset_with_relationships
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_arguments(arguments)
              |> api.update(opts)
              |> update_result()

            Absinthe.Resolution.put_result(resolution, to_resolution(result))
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource, %{type: :destroy, action: action, identity: identity}}
      ) do
    filter =
      if identity do
        {:ok,
         resource
         |> Ash.Resource.identities()
         |> Enum.find(&(&1.name == identity))
         |> Map.get(:keys)
         |> Enum.map(fn key ->
           {key, Map.get(arguments, key)}
         end)}
      else
        case AshGraphql.Resource.decode_primary_key(resource, Map.get(arguments, :id) || "") do
          {:ok, value} -> {:ok, [id: value]}
          {:error, error} -> {:error, error}
        end
      end

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> set_query_arguments(action, arguments)
        |> api.read_one!()
        |> case do
          nil ->
            {:ok, %{result: nil, errors: [to_errors("not found")]}}

          initial ->
            opts = destroy_opts(api, context, action)

            result =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> api.destroy(opts)
              |> destroy_result(initial)

            Absinthe.Resolution.put_result(resolution, to_resolution(result))
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  end

  defp set_query_arguments(query, action, arg_values) do
    action = Ash.Resource.action(query.resource, action, :read)

    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.reduce(query, fn argument, query ->
      Ash.Query.set_argument(query, argument.name, Map.get(arg_values, argument.name))
    end)
  end

  defp destroy_opts(api, context, action) do
    if AshGraphql.Api.authorize?(api) do
      [actor: Map.get(context, :actor), action: action]
    else
      [action: action]
    end
  end

  defp update_result(result) do
    case result do
      {:ok, value} ->
        {:ok, %{result: value, errors: []}}

      {:error, error} ->
        {:ok, %{result: nil, errors: List.wrap(error)}}
    end
  end

  defp destroy_result(result, initial) do
    case result do
      :ok -> {:ok, %{result: initial, errors: []}}
      {:error, error} -> {:ok, %{result: nil, errors: to_errors(error)}}
    end
  end

  defp changeset_with_relationships(relationships, changeset) do
    Enum.reduce(relationships, changeset, fn {relationship, replacement}, changeset ->
      case decode_related_pkeys(changeset, relationship, replacement) do
        {:ok, replacement} ->
          Ash.Changeset.replace_relationship(changeset, relationship, replacement)

        {:error, _error} ->
          Ash.Changeset.add_error(changeset, "Invalid relationship primary keys")
      end
    end)
  end

  defp decode_related_pkeys(changeset, relationship, primary_keys)
       when is_list(primary_keys) do
    primary_keys
    |> Enum.reduce_while({:ok, []}, fn pkey, {:ok, list} ->
      case AshGraphql.Resource.decode_primary_key(
             Ash.Resource.related(changeset.resource, relationship),
             pkey
           ) do
        {:ok, value} -> {:cont, {:ok, [value | list]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp decode_related_pkeys(changeset, relationship, primary_key) do
    AshGraphql.Resource.decode_primary_key(
      Ash.Resource.related(changeset.resource, relationship),
      primary_key
    )
  end

  defp split_attrs_rels_and_args(input, resource) do
    Enum.reduce(input, {%{}, %{}, %{}}, fn {key, value}, {attrs, rels, args} ->
      cond do
        Ash.Resource.public_attribute(resource, key) ->
          {Map.put(attrs, key, value), rels, args}

        Ash.Resource.public_relationship(resource, key) ->
          {attrs, Map.put(rels, key, value), args}

        true ->
          {attrs, rels, Map.put(args, key, value)}
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
      args: args,
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

      {:sort, value}, query ->
        keyword_sort =
          Enum.map(value, fn %{order: order, field: field} ->
            {field, order}
          end)

        Ash.Query.sort(query, keyword_sort)
    end)
  end

  defp decode_and_filter(query, value) do
    Ash.Query.filter(query, ^value)
  end

  defp to_resolution({:ok, value}), do: {:ok, value}

  defp to_resolution({:error, error}),
    do: {:error, error |> List.wrap() |> Enum.map(&Exception.message(&1))}
end
