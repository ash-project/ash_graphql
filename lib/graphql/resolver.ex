defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Ash.Query
  require Logger

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {api, resource, %{type: :get, action: action, identity: identity}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api)
    ]

    filter =
      if identity do
        {:ok,
         resource
         |> Ash.Resource.Info.identities()
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
          |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
          |> Ash.Query.filter(^filter)
          |> set_query_arguments(action, arguments)
          |> select_fields(resource, resolution)
          |> load_fields(resource, api, resolution)
          |> case do
            {:ok, query} ->
              api.read_one(query, opts)

            {:error, error} ->
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {api, resource, %{type: :read_one, action: action}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api)
    ]

    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          Ash.Query.filter(resource, ^filter)

        _ ->
          Ash.Query.new(resource)
      end

    result =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
      |> set_query_arguments(action, args)
      |> select_fields(resource, resolution)
      |> load_fields(resource, api, resolution)
      |> case do
        {:ok, query} ->
          api.read_one(query, opts)

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
      action: action,
      verbose?: AshGraphql.Api.debug?(api)
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

    nested =
      if Ash.Resource.Info.action(resource, action, :read).pagination do
        "results"
      else
        nil
      end

    result =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
      |> set_query_arguments(action, args)
      |> select_fields(resource, resolution, nested)
      |> load_fields(resource, api, resolution, nested)
      |> case do
        {:ok, query} ->
          query =
            if query.filter do
              aggregates = Ash.Filter.used_aggregates(query.filter)

              Ash.Query.load(query, aggregates)
            else
              query
            end

          query =
            if query.sort do
              fields =
                Enum.map(query.sort, fn
                  {field, _} ->
                    field

                  field ->
                    field
                end)
                |> Enum.filter(fn field ->
                  Ash.Resource.Info.public_aggregate(query.resource, field)
                end)

              Ash.Query.load(query, fields)
            else
              query
            end

          query
          |> api.read(opts)
          |> case do
            {:ok, %{results: results, count: count}} ->
              {:ok, %{results: results, count: count}}

            {:ok, results} ->
              if Ash.Resource.Info.action(resource, action, :read).pagination do
                {:ok, %{results: results, count: Enum.count(results)}}
              else
                {:ok, results}
              end

            error ->
              error
          end

        {:error, error} ->
          {:error, error}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{input: input}, context: context} = resolution,
        {api, resource, %{type: :create, action: action, upsert?: upsert?}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api),
      upsert?: upsert?
    ]

    result =
      resource
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
      |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
      |> Ash.Changeset.for_create(action, input, actor: Map.get(context, :actor))
      |> select_fields(resource, resolution, "result")
      |> api.create(opts)
      |> case do
        {:ok, value} ->
          case load_fields(value, resource, api, resolution, "result") do
            {:ok, result} ->
              {:ok, %{result: result, errors: []}}

            {:error, error} ->
              {:ok, %{result: nil, errors: to_errors(List.wrap(error))}}
          end

        {:error, %{changeset: changeset}} ->
          {:ok, %{result: nil, errors: to_errors(changeset.errors)}}
      end

    Absinthe.Resolution.put_result(resolution, to_resolution(result))
  end

  def mutate(
        %{arguments: %{input: input} = arguments, context: context} = resolution,
        {api, resource,
         %{type: :update, action: action, identity: identity, read_action: read_action}}
      ) do
    filter = identity_filter(identity, resource, arguments)

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
        |> set_query_arguments(action, arguments)
        |> api.read_one!(action: read_action, verbose?: AshGraphql.Api.debug?(api))
        |> case do
          nil ->
            result = not_found(filter, resource)

            Absinthe.Resolution.put_result(resolution, result)

          initial ->
            opts = [
              actor: Map.get(context, :actor),
              authorize?: AshGraphql.Api.authorize?(api),
              action: action,
              verbose?: AshGraphql.Api.debug?(api)
            ]

            result =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> Ash.Changeset.for_update(action, input, actor: Map.get(context, :actor))
              |> Ash.Changeset.set_arguments(arguments)
              |> select_fields(resource, resolution, "result")
              |> api.update(opts)
              |> update_result(resource, api, resolution)

            Absinthe.Resolution.put_result(resolution, to_resolution(result))
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{type: :destroy, action: action, identity: identity, read_action: read_action}}
      ) do
    filter = identity_filter(identity, resource, arguments)

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
        |> set_query_arguments(action, arguments)
        |> api.read_one!(action: read_action, verbose?: AshGraphql.Api.debug?(api))
        |> case do
          nil ->
            result = not_found(filter, resource)

            Absinthe.Resolution.put_result(resolution, result)

          initial ->
            opts = destroy_opts(api, context, action)

            result =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> select_fields(resource, resolution, "result")
              |> api.destroy(opts)
              |> destroy_result(initial, resource, resolution)

            Absinthe.Resolution.put_result(resolution, to_resolution(result))
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  end

  def identity_filter(false, _resource, _arguments) do
    {:ok, nil}
  end

  def identity_filter(nil, resource, arguments) do
    case AshGraphql.Resource.decode_primary_key(resource, Map.get(arguments, :id) || "") do
      {:ok, value} -> {:ok, [id: value]}
      {:error, error} -> {:error, error}
    end
  end

  def identity_filter(identity, resource, arguments) do
    {:ok,
     resource
     |> Ash.Resource.Info.identities()
     |> Enum.find(&(&1.name == identity))
     |> Map.get(:keys)
     |> Enum.map(fn key ->
       {key, Map.get(arguments, key)}
     end)}
  end

  defp not_found(filter, resource) do
    {:ok,
     %{
       result: nil,
       errors:
         to_errors(
           Ash.Error.Query.NotFound.exception(
             primary_key: Map.new(filter),
             resource: resource
           )
         )
     }}
  end

  defp clear_fields(nil, _, _), do: nil

  defp clear_fields(result, resource, resolution) do
    resolution
    |> fields("result")
    |> Enum.map(fn identifier ->
      Ash.Resource.Info.aggregate(resource, identifier) ||
        Ash.Resource.Info.calculation(resource, identifier)
    end)
    |> Enum.filter(& &1)
    |> Enum.map(& &1.name)
    |> Enum.reduce(result, fn field, result ->
      Map.put(result, field, nil)
    end)
  end

  defp load_fields(query_or_record, resource, api, resolution, nested \\ nil) do
    loading =
      resolution
      |> fields(nested)
      |> Enum.map(fn identifier ->
        Ash.Resource.Info.aggregate(resource, identifier) ||
          Ash.Resource.Info.calculation(resource, identifier)
      end)
      |> Enum.filter(& &1)
      |> Enum.map(& &1.name)

    case query_or_record do
      %Ash.Query{} = query ->
        {:ok, Ash.Query.load(query, loading)}

      record ->
        api.load(record, loading)
    end
  end

  defp select_fields(query_or_changeset, resource, resolution, nested \\ nil) do
    subfields =
      resolution
      |> fields(nested)
      |> Enum.map(&field_or_relationship(resource, &1))
      |> Enum.filter(& &1)
      |> Enum.map(& &1.name)

    case query_or_changeset do
      %Ash.Query{} = query ->
        Ash.Query.select(query, subfields)

      %Ash.Changeset{} = changeset ->
        Ash.Changeset.select(changeset, subfields)
    end
  end

  defp field_or_relationship(resource, identifier) do
    case Ash.Resource.Info.attribute(resource, identifier) do
      nil ->
        case Ash.Resource.Info.relationship(resource, identifier) do
          nil ->
            nil

          rel ->
            Ash.Resource.Info.attribute(resource, rel.source_field)
        end

      attr ->
        attr
    end
  end

  defp fields(resolution, nested) do
    if nested do
      projected_once =
        resolution
        |> Absinthe.Resolution.project()
        |> Enum.find(&(&1.name == nested))

      type = Absinthe.Schema.lookup_type(resolution.schema, projected_once.schema_node.type)

      projected_once
      |> Map.get(:selections)
      |> Absinthe.Resolution.Projector.project(
        type,
        resolution.path ++ [projected_once],
        resolution.fields_cache,
        resolution
      )
      |> elem(0)
      |> Enum.map(fn %{schema_node: %{identifier: identifier}} ->
        identifier
      end)
    else
      resolution
      |> Absinthe.Resolution.project()
      |> Enum.map(fn %{schema_node: %{identifier: identifier}} ->
        identifier
      end)
    end
  end

  defp set_query_arguments(query, action, arg_values) do
    action = Ash.Resource.Info.action(query.resource, action, :read)

    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.reduce(query, fn argument, query ->
      Ash.Query.set_argument(query, argument.name, Map.get(arg_values, argument.name))
    end)
  end

  defp destroy_opts(api, context, action) do
    if AshGraphql.Api.authorize?(api) do
      [actor: Map.get(context, :actor), action: action, verbose?: AshGraphql.Api.debug?(api)]
    else
      [action: action, verbose?: AshGraphql.Api.debug?(api)]
    end
  end

  defp update_result(result, resource, api, resolution) do
    case result do
      {:ok, value} ->
        case load_fields(value, resource, api, resolution, "result") do
          {:ok, result} ->
            {:ok, %{result: result, errors: []}}

          {:error, error} ->
            {:ok, %{result: nil, errors: to_errors(List.wrap(error))}}
        end

      {:error, error} ->
        {:ok, %{result: nil, errors: to_errors(List.wrap(error))}}
    end
  end

  defp destroy_result(result, initial, resource, resolution) do
    case result do
      :ok ->
        {:ok, %{result: clear_fields(initial, resource, resolution), errors: []}}

      {:error, %{changeset: changeset}} ->
        {:ok, %{result: nil, errors: to_errors(changeset.error)}}
    end
  end

  defp to_errors(errors) do
    errors
    |> List.wrap()
    |> Enum.flat_map(fn
      %Ash.Error.Invalid{errors: errors} ->
        List.wrap(errors)

      errors ->
        List.wrap(errors)
    end)
    |> Enum.map(fn error ->
      if AshGraphql.Error.impl_for(error) do
        AshGraphql.Error.to_error(error)
      else
        uuid = Ash.UUID.generate()
        Logger.warn("`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{inspect(error)}")

        %{
          message: "something went wrong. Unique error id: `#{uuid}`"
        }
      end
    end)
  end

  def resolve_assoc(
        %{source: parent, arguments: args, context: %{loader: loader} = context} = resolution,
        {api, relationship}
      ) do
    api_opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      verbose?: AshGraphql.Api.debug?(api)
    ]

    related_query =
      args
      |> apply_load_arguments(Ash.Query.new(relationship.destination))
      |> select_fields(relationship.destination, resolution)

    opts = [
      query: related_query,
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
