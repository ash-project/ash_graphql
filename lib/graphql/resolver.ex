defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Ash.Query
  require Logger

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{type: :get, action: action, identity: identity, modify_resolution: modify}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api),
      stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
    ]

    filter = identity_filter(identity, resource, arguments)

    query =
      resource
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
      |> set_query_arguments(action, arguments)
      |> select_fields(resource, resolution)

    {result, modify_args} =
      case filter do
        {:ok, filter} ->
          query
          |> Ash.Query.filter(^filter)
          |> load_fields(resource, api, resolution)
          |> case do
            {:ok, query} ->
              result =
                query
                |> Ash.Query.for_read(action, %{}, actor: opts[:actor])
                |> api.read_one(opts)

              {result, [query, result]}

            {:error, error} ->
              {{:error, error}, [query, {:error, error}]}
          end

        {:error, error} ->
          query =
            resource
            |> Ash.Query.new()
            |> Ash.Query.set_tenant(Map.get(context, :tenant))
            |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
            |> set_query_arguments(action, arguments)
            |> select_fields(resource, resolution)
            |> load_fields(resource, api, resolution)

          {{:error, error}, [query, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {api, resource, %{type: :read_one, action: action, modify_resolution: modify}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api),
      stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
    ]

    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          Ash.Query.filter(resource, ^filter)

        _ ->
          Ash.Query.new(resource)
      end

    query =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
      |> set_query_arguments(action, args)
      |> select_fields(resource, resolution)

    {result, modify_args} =
      case load_fields(query, resource, api, resolution) do
        {:ok, query} ->
          result = api.read_one(query, opts)
          {result, [query, result]}

        {:error, error} ->
          {{:error, error}, [query, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {api, resource, %{type: :list, action: action, modify_resolution: modify}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api),
      stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
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
          if Enum.any?(fields(resolution), &(&1 == :count)) do
            page_opts = Keyword.put(page_opts, :count, true)
            Keyword.put(opts, :page, page_opts)
          else
            Keyword.put(opts, :page, page_opts)
          end
      end

    query = load_filter_and_sort_requirements(resource, args)

    nested =
      if Ash.Resource.Info.action(resource, action, :read).pagination do
        "results"
      else
        nil
      end

    initial_query =
      query
      |> Ash.Query.set_tenant(Map.get(context, :tenant))
      |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
      |> set_query_arguments(action, args)
      |> select_fields(resource, resolution, nested)

    {result, modify_args} =
      case load_fields(initial_query, resource, api, resolution, nested) do
        {:ok, query} ->
          query
          |> api.read(opts)
          |> case do
            {:ok, %{results: results, count: count} = page} ->
              {{:ok, %{results: results, count: count}}, [query, {:ok, page}]}

            {:ok, results} ->
              if Ash.Resource.Info.action(resource, action, :read).pagination do
                result = {:ok, %{results: results, count: Enum.count(results)}}
                {result, [query, result]}
              else
                result = {:ok, results}
                {result, [query, result]}
              end

            error ->
              {error, [query, error]}
          end

        {:error, error} ->
          {{:error, error}, [query, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{type: :create, action: action, upsert?: upsert?, modify_resolution: modify}}
      ) do
    input = arguments[:input] || %{}

    opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.authorize?(api),
      action: action,
      verbose?: AshGraphql.Api.debug?(api),
      stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api),
      upsert?: upsert?
    ]

    changeset =
      resource
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
      |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
      |> Ash.Changeset.for_create(action, input, actor: Map.get(context, :actor))
      |> select_fields(resource, resolution, "result")

    {result, modify_args} =
      changeset
      |> api.create(opts)
      |> case do
        {:ok, value} ->
          case load_fields(value, resource, api, resolution, "result") do
            {:ok, result} ->
              {{:ok, %{result: result, errors: []}}, [changeset, {:ok, result}]}

            {:error, error} ->
              {{:ok, %{result: nil, errors: to_errors(List.wrap(error))}},
               [changeset, {:error, error}]}
          end

        {:error, %{changeset: changeset} = error} ->
          {{:ok, %{result: nil, errors: to_errors(changeset.errors)}}, [changeset, error]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{
           type: :update,
           action: action,
           identity: identity,
           read_action: read_action,
           modify_resolution: modify
         }}
      ) do
    input = arguments[:input] || %{}
    filter = identity_filter(identity, resource, arguments)

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
        |> set_query_arguments(action, arguments)
        |> api.read_one!(
          action: read_action,
          verbose?: AshGraphql.Api.debug?(api),
          stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api),
          actor: Map.get(context, :actor),
          authorize?: AshGraphql.Api.authorize?(api)
        )
        |> case do
          nil ->
            result = not_found(filter, resource)

            Absinthe.Resolution.put_result(resolution, result)

          initial ->
            opts = [
              actor: Map.get(context, :actor),
              authorize?: AshGraphql.Api.authorize?(api),
              action: action,
              verbose?: AshGraphql.Api.debug?(api),
              stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
            ]

            changeset =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> Ash.Changeset.for_update(action, input, actor: Map.get(context, :actor))
              |> Ash.Changeset.set_arguments(arguments)
              |> select_fields(resource, resolution, "result")

            {result, modify_args} =
              changeset
              |> api.update(opts)
              |> update_result(resource, api, changeset, resolution)

            resolution
            |> Absinthe.Resolution.put_result(to_resolution(result))
            |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{
           type: :destroy,
           action: action,
           identity: identity,
           read_action: read_action,
           modify_resolution: modify
         }}
      ) do
    filter = identity_filter(identity, resource, arguments)
    input = arguments[:input] || %{}

    case filter do
      {:ok, filter} ->
        resource
        |> Ash.Query.filter(^filter)
        |> Ash.Query.set_tenant(Map.get(context, :tenant))
        |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
        |> set_query_arguments(action, arguments)
        |> api.read_one!(
          action: read_action,
          verbose?: AshGraphql.Api.debug?(api),
          stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
        )
        |> case do
          nil ->
            result = not_found(filter, resource)

            Absinthe.Resolution.put_result(resolution, result)

          initial ->
            opts = destroy_opts(api, context, action)

            changeset =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> Ash.Changeset.for_destroy(action, input, actor: Map.get(context, :actor))
              |> Ash.Changeset.set_arguments(arguments)
              |> select_fields(resource, resolution, "result")

            {result, modify_args} =
              changeset
              |> api.destroy(opts)
              |> destroy_result(initial, resource, changeset, resolution)

            resolution
            |> Absinthe.Resolution.put_result(to_resolution(result))
            |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  rescue
    e ->
      error = Ash.Error.to_ash_error([e], __STACKTRACE__)
      Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
  end

  defp modify_resolution(resolution, nil, _), do: resolution

  defp modify_resolution(resolution, {m, f, a}, args) do
    apply(m, f, [resolution | args] ++ a)
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
             primary_key: Map.new(filter || []),
             resource: resource
           )
         )
     }}
  end

  defp load_filter_and_sort_requirements(resource, args) do
    query =
      case Map.fetch(args, :filter) do
        {:ok, filter} ->
          Ash.Query.filter(resource, ^massage_filter(resource, filter))

        _ ->
          Ash.Query.new(resource)
      end

    case Map.fetch(args, :sort) do
      {:ok, sort} ->
        keyword_sort =
          Enum.map(sort, fn %{order: order, field: field} ->
            {field, order}
          end)

        fields =
          keyword_sort
          |> Keyword.keys()
          |> Enum.filter(&Ash.Resource.Info.public_aggregate(resource, &1))

        query
        |> Ash.Query.load(fields)
        |> Ash.Query.sort(keyword_sort)

      _ ->
        query
    end
  end

  defp massage_filter(_resource, nil), do: nil

  defp massage_filter(resource, filter) when is_map(filter) do
    Map.new(filter, fn {key, value} ->
      cond do
        rel = Ash.Resource.Info.relationship(resource, key) ->
          {key, massage_filter(rel.destination, value)}

        Ash.Resource.Info.calculation(resource, key) ->
          calc_input(key, value)

        true ->
          {key, value}
      end
    end)
  end

  defp massage_filter(_resource, other), do: other

  defp calc_input(key, value) do
    case Map.fetch(value, :input) do
      {:ok, input} ->
        {key, {input, Map.delete(value, :input)}}

      :error ->
        {key, value}
    end
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
    fields = fields(resolution, nested, false)

    fields
    |> Enum.map(fn selection ->
      aggregate = Ash.Resource.Info.aggregate(resource, selection.schema_node.identifier)

      if aggregate do
        aggregate.name
      else
        calculation = Ash.Resource.Info.calculation(resource, selection.schema_node.identifier)

        if calculation do
          {calculation.name, selection.argument_data || %{}}
        end
      end
    end)
    |> Enum.filter(& &1)
    |> case do
      [] ->
        {:ok, query_or_record}

      loading ->
        case query_or_record do
          %Ash.Query{} = query ->
            {:ok, Ash.Query.load(query, loading)}

          record ->
            api.load(record, loading)
        end
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

  defp fields(resolution, nested \\ nil, names_only? \\ true) do
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
      |> names_only(names_only?)
    else
      resolution
      |> Absinthe.Resolution.project()
      |> names_only(names_only?)
    end
  end

  defp names_only(fields, true) do
    Enum.map(fields, fn %{schema_node: %{identifier: identifier}} ->
      identifier
    end)
  end

  defp names_only(fields, _) do
    fields
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
      [
        actor: Map.get(context, :actor),
        action: action,
        verbose?: AshGraphql.Api.debug?(api),
        stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
      ]
    else
      [
        action: action,
        verbose?: AshGraphql.Api.debug?(api),
        stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
      ]
    end
  end

  defp update_result(result, resource, api, changeset, resolution) do
    case result do
      {:ok, value} ->
        case load_fields(value, resource, api, resolution, "result") do
          {:ok, result} ->
            {{:ok, %{result: result, errors: []}}, [changeset, {:ok, result}]}

          {:error, error} ->
            # Even though the loading of fields failed, the mutation was successful
            {{:ok, %{result: nil, errors: to_errors(List.wrap(error))}}, {:ok, value}}
        end

      {:error, error} ->
        {{:ok, %{result: nil, errors: to_errors(List.wrap(error))}}, {:ok, result}}
    end
  end

  defp destroy_result(result, initial, resource, changeset, resolution) do
    case result do
      :ok ->
        {{:ok, %{result: clear_fields(initial, resource, resolution), errors: []}},
         [changeset, :ok]}

      {:error, %{changeset: changeset} = error} ->
        {{:ok, %{result: nil, errors: to_errors(changeset.error)}}, {:error, error}}
    end
  end

  defp unwrap_errors([]), do: []

  defp unwrap_errors(errors) do
    errors
    |> List.wrap()
    |> Enum.flat_map(fn
      %Ash.Error.Invalid{errors: errors} ->
        unwrap_errors(List.wrap(errors))

      errors ->
        List.wrap(errors)
    end)
  end

  defp to_errors(errors) do
    errors
    |> unwrap_errors()
    |> Enum.map(fn error ->
      if AshGraphql.Error.impl_for(error) do
        AshGraphql.Error.to_error(error)
      else
        uuid = Ash.UUID.generate()

        if is_exception(error) do
          case error do
            %{stacktrace: %{stacktrace: stacktrace}} ->
              Logger.warn(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{
                  Exception.format(:error, error, stacktrace)
                }"
              )

            error ->
              Logger.warn(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{
                  Exception.format(:error, error)
                }"
              )
          end
        else
          Logger.warn(
            "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{inspect(error)}"
          )
        end

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
      verbose?: AshGraphql.Api.debug?(api),
      stacktraces?: AshGraphql.Api.debug?(api) || AshGraphql.Api.stacktraces?(api)
    ]

    query = load_filter_and_sort_requirements(relationship.destination, args)

    args
    |> apply_load_arguments(query)
    |> select_fields(relationship.destination, resolution)
    |> load_fields(relationship.destination, api, resolution)
    |> case do
      {:ok, related_query} ->
        opts = [
          query: related_query,
          api_opts: api_opts,
          args: args,
          tenant: Map.get(context, :tenant)
        ]

        {batch_key, parent} = {{relationship.name, opts}, parent}
        do_dataloader(resolution, loader, api, batch_key, args, parent)

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
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

  defp to_resolution({:error, error}) do
    {:error,
     error
     |> unwrap_errors()
     |> Enum.map(fn error ->
       if AshGraphql.Error.impl_for(error) do
         AshGraphql.Error.to_error(error) |> Map.to_list()
       else
         uuid = Ash.UUID.generate()

         stacktrace =
           case error do
             %{stacktrace: %{stacktrace: v}} ->
               v

             _ ->
               nil
           end

         Logger.warn(
           "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{
             Exception.format(:error, error, stacktrace)
           }"
         )

         [
           message: "something went wrong. Unique error id: `#{uuid}`"
         ]
       end
     end)}
  end
end
