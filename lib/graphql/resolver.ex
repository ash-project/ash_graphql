defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Ash.Query
  require Logger

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{type: :get, action: action, identity: identity, modify_resolution: modify} = gql_query}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      action: action,
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
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
                |> Ash.Query.for_read(action, %{},
                  actor: opts[:actor],
                  authorize?: AshGraphql.Api.Info.authorize?(api)
                )
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

    case {result, gql_query.allow_nil?} do
      {{:ok, nil}, false} ->
        {:ok, filter} = filter
        result = not_found(filter, resource)

        resolution
        |> Absinthe.Resolution.put_result(result)
        |> add_root_errors(api, result)

      {result, _} ->
        resolution
        |> Absinthe.Resolution.put_result(to_resolution(result))
        |> add_root_errors(api, result)
        |> modify_resolution(modify, modify_args)
    end
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
      else
        something_went_wrong(resolution, e)
      end
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {api, resource, %{type: :read_one, action: action, modify_resolution: modify}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      action: action,
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
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
          result =
            query
            |> Ash.Query.for_read(action, %{},
              actor: opts[:actor],
              authorize?: AshGraphql.Api.Info.authorize?(api)
            )
            |> api.read_one(opts)

          {result, [query, result]}

        {:error, error} ->
          {{:error, error}, [query, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> add_root_errors(api, result)
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
      else
        something_went_wrong(resolution, e)
      end
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {api, resource, %{type: :list, action: action, modify_resolution: modify}}
      ) do
    opts = [
      actor: Map.get(context, :actor),
      action: action,
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
    ]

    pagination = Ash.Resource.Info.action(resource, action).pagination
    query = load_filter_and_sort_requirements(resource, args)

    {result, modify_args} =
      with {:ok, opts} <- validate_resolve_opts(resolution, pagination, opts, args),
           result_fields <- get_result_fields(pagination),
           initial_query <-
             query
             |> Ash.Query.set_tenant(Map.get(context, :tenant))
             |> Ash.Query.set_context(Map.get(context, :ash_context) || %{})
             |> set_query_arguments(action, args)
             |> select_fields(resource, resolution, result_fields),
           {:ok, query} <- load_fields(initial_query, resource, api, resolution, result_fields),
           {:ok, page} <-
             query
             |> Ash.Query.for_read(action, %{},
               actor: Map.get(context, :actor),
               authorize?: AshGraphql.Api.Info.authorize?(api)
             )
             |> api.read(opts) do
        result = paginate(resource, action, page)
        {result, [query, result]}
      else
        {:error, error} ->
          {{:error, error}, [query, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> add_root_errors(api, modify_args)
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
      else
        something_went_wrong(resolution, e)
      end
  end

  def validate_resolve_opts(resolution, pagination, opts, args) do
    case args
         |> Map.take([:limit, :offset, :first, :after, :before, :last])
         |> Enum.reject(fn {_, val} -> is_nil(val) end)
         |> validate_pagination_opts(pagination) do
      {:ok, []} ->
        {:ok, opts}

      {:ok, page_opts} ->
        page_fields = get_page_fields(pagination)
        field_names = resolution |> fields(page_fields) |> names_only()

        page =
          if Enum.any?(field_names, &(&1 == :count)) do
            Keyword.put(page_opts, :count, true)
          else
            page_opts
          end

        {:ok, Keyword.put(opts, :page, page)}

      error ->
        error
    end
  end

  defp validate_pagination_opts(opts, %{offset?: true, max_page_size: max_page_size}) do
    limit =
      case opts |> Keyword.take([:limit]) |> Enum.into(%{}) do
        %{limit: limit} ->
          min(limit, max_page_size)

        _ ->
          max_page_size
      end

    {:ok, Keyword.put(opts, :limit, limit)}
  end

  defp validate_pagination_opts(opts, %{keyset?: true, max_page_size: max_page_size}) do
    case opts |> Keyword.take([:first, :last, :after, :before]) |> Enum.into(%{}) do
      %{first: _first, last: _last} ->
        {:error,
         %Ash.Error.Query.InvalidQuery{
           message: "You can pass either `first` or `last`, not both",
           field: :first
         }}

      %{first: _first, before: _before} ->
        {:error,
         %Ash.Error.Query.InvalidQuery{
           message:
             "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
           field: :first
         }}

      %{last: _last, after: _after} ->
        {:error,
         %Ash.Error.Query.InvalidQuery{
           message:
             "You can pass either `first` and `after` cursor, or `last` and `before` cursor",
           field: :last
         }}

      %{first: first} ->
        {:ok, opts |> Keyword.delete(:first) |> Keyword.put(:limit, min(first, max_page_size))}

      %{last: last, before: before} when not is_nil(before) ->
        {:ok, opts |> Keyword.delete(:last) |> Keyword.put(:limit, min(last, max_page_size))}

      %{last: _last} ->
        {:error,
         %Ash.Error.Query.InvalidQuery{
           message: "You can pass `last` only with `before` cursor",
           field: :last
         }}

      _ ->
        {:ok, Keyword.put(opts, :limit, max_page_size)}
    end
  end

  defp validate_pagination_opts(opts, _) do
    {:ok, opts}
  end

  defp get_result_fields(%{keyset?: true}) do
    ["edges", "node"]
  end

  defp get_result_fields(%{offset?: true}) do
    ["results"]
  end

  defp get_result_fields(_pagination) do
    []
  end

  defp get_page_fields(%{keyset?: true}) do
    ["pageInfo"]
  end

  defp get_page_fields(_pagination) do
    []
  end

  defp paginate(_resource, _action, %Ash.Page.Keyset{
         results: results,
         more?: more,
         after: after_cursor,
         before: before_cursor
       }) do
    {start_cursor, end_cursor} =
      case results do
        [] ->
          {nil, nil}

        [first] ->
          {first.__metadata__.keyset, first.__metadata__.keyset}

        [first | rest] ->
          last = List.last(rest)
          {first.__metadata__.keyset, last.__metadata__.keyset}
      end

    {has_previous_page, has_next_page} =
      case {after_cursor, before_cursor} do
        {nil, nil} ->
          {false, more}

        {_, nil} ->
          {true, more}

        {nil, _} ->
          # https://github.com/ash-project/ash_graphql/pull/36#issuecomment-1243892511
          {more, not Enum.empty?(results)}
      end

    {
      :ok,
      %{
        page_info: %{
          start_cursor: start_cursor,
          end_cursor: end_cursor,
          has_next_page: has_next_page,
          has_previous_page: has_previous_page
        },
        edges:
          Enum.map(results, fn result ->
            %{
              cursor: result.__metadata__.keyset,
              node: result
            }
          end)
      }
    }
  end

  defp paginate(_resource, _action, %Ash.Page.Offset{results: results, count: count}) do
    {:ok, %{results: results, count: count}}
  end

  defp paginate(resource, action, page) do
    case Ash.Resource.Info.action(resource, action).pagination do
      %{offset?: true} ->
        paginate(resource, action, %Ash.Page.Offset{results: page, count: Enum.count(page)})

      %{keyset?: true} ->
        paginate(resource, action, %Ash.Page.Keyset{
          results: page,
          more?: false,
          after: nil,
          before: nil
        })

      _ ->
        {:ok, page}
    end
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {api, resource,
         %{type: :create, action: action, upsert?: upsert?, modify_resolution: modify}}
      ) do
    input = arguments[:input] || %{}

    opts = [
      actor: Map.get(context, :actor),
      action: action,
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api),
      upsert?: upsert?,
      after_action: fn _changeset, result ->
        load_fields(result, resource, api, resolution, ["result"])
      end
    ]

    changeset =
      resource
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
      |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
      |> Ash.Changeset.for_create(action, input,
        actor: Map.get(context, :actor),
        authorize?: AshGraphql.Api.Info.authorize?(api)
      )
      |> select_fields(resource, resolution, ["result"])

    {result, modify_args} =
      changeset
      |> api.create(opts)
      |> case do
        {:ok, value} ->
          {{:ok, add_metadata(%{result: value, errors: []}, value, changeset.action)},
           [changeset, {:ok, value}]}

        {:error, %{changeset: changeset} = error} ->
          {{:ok, %{result: nil, errors: to_errors(changeset.errors)}},
           [changeset, {:error, error}]}
      end

    resolution
    |> Absinthe.Resolution.put_result(to_resolution(result))
    |> add_root_errors(api, modify_args)
    |> modify_resolution(modify, modify_args)
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Api.Info.root_level_errors?(api) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error})
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:ok, %{result: nil, errors: to_errors(error)}})
          )
        end
      else
        something_went_wrong(resolution, e)
      end
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
          verbose?: AshGraphql.Api.Info.debug?(api),
          stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api),
          actor: Map.get(context, :actor),
          authorize?: AshGraphql.Api.Info.authorize?(api)
        )
        |> case do
          nil ->
            result = not_found(filter, resource)

            resolution
            |> Absinthe.Resolution.put_result(result)
            |> add_root_errors(api, result)

          initial ->
            opts = [
              actor: Map.get(context, :actor),
              action: action,
              verbose?: AshGraphql.Api.Info.debug?(api),
              stacktraces?:
                AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api),
              after_action: fn _changeset, result ->
                load_fields(result, resource, api, resolution, ["result"])
              end
            ]

            changeset =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> Ash.Changeset.for_update(action, input,
                actor: Map.get(context, :actor),
                authorize?: AshGraphql.Api.Info.authorize?(api)
              )
              |> Ash.Changeset.set_arguments(arguments)
              |> select_fields(resource, resolution, ["result"])

            {result, modify_args} =
              changeset
              |> api.update(opts)
              |> case do
                {:ok, value} ->
                  {{:ok, add_metadata(%{result: value, errors: []}, value, changeset.action)},
                   [changeset, {:ok, value}]}

                {:error, error} ->
                  {{:ok, %{result: nil, errors: to_errors(List.wrap(error))}},
                   [changeset, {:error, error}]}
              end

            resolution
            |> Absinthe.Resolution.put_result(to_resolution(result))
            |> add_root_errors(api, modify_args)
            |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Api.Info.root_level_errors?(api) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error})
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:ok, %{result: nil, errors: to_errors(error)}})
          )
        end
      else
        something_went_wrong(resolution, e)
      end
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
          verbose?: AshGraphql.Api.Info.debug?(api),
          stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api),
          actor: Map.get(context, :actor),
          authorize?: AshGraphql.Api.Info.authorize?(api)
        )
        |> case do
          nil ->
            result = not_found(filter, resource)

            resolution
            |> Absinthe.Resolution.put_result(result)
            |> add_root_errors(api, result)

          initial ->
            opts = destroy_opts(api, context, action)

            changeset =
              initial
              |> Ash.Changeset.new()
              |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
              |> Ash.Changeset.set_context(Map.get(context, :ash_context) || %{})
              |> Ash.Changeset.for_destroy(action, input,
                actor: Map.get(context, :actor),
                authorize?: AshGraphql.Api.Info.authorize?(api)
              )
              |> Ash.Changeset.set_arguments(arguments)
              |> select_fields(resource, resolution, ["result"])

            {result, modify_args} =
              changeset
              |> api.destroy(opts)
              |> destroy_result(initial, resource, changeset, resolution)

            resolution
            |> Absinthe.Resolution.put_result(to_resolution(result))
            |> add_root_errors(api, result)
            |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  rescue
    e ->
      if AshGraphql.Api.Info.show_raised_errors?(api) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Api.Info.root_level_errors?(api) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error})
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:ok, %{result: nil, errors: to_errors(error)}})
          )
        end
      else
        something_went_wrong(resolution, e)
      end
  end

  defp log_exception(e) do
    uuid = Ash.UUID.generate()

    Logger.error("""
    #{uuid}: Exception raised while resolving query.

    #{Exception.message(e)}
    """)

    uuid
  end

  defp something_went_wrong(resolution, e) do
    uuid = log_exception(e)

    Absinthe.Resolution.put_result(
      resolution,
      {:error,
       [
         %{
           message: "Something went wrong. Unique error id: `#{uuid}`",
           code: "something_went_wrong",
           vars: %{},
           fields: [],
           short_message: "Something went wrong."
         }
       ]}
    )
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
      {:ok, value} ->
        {:ok, value}

      {:error, error} ->
        {:error, error}
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
    |> fields(["result"])
    |> names_only()
    |> Enum.map(fn identifier ->
      Ash.Resource.Info.aggregate(resource, identifier)
    end)
    |> Enum.filter(& &1)
    |> Enum.map(& &1.name)
    |> Enum.reduce(result, fn field, result ->
      Map.put(result, field, nil)
    end)
  end

  defp load_fields(query_or_record, resource, api, resolution, nested \\ []) do
    fields = fields(resolution, nested)

    fields
    |> Enum.map(fn selection ->
      aggregate = Ash.Resource.Info.aggregate(resource, selection.schema_node.identifier)

      if aggregate do
        aggregate.name
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

  defp select_fields(query_or_changeset, resource, resolution, nested \\ []) do
    subfields =
      resolution
      |> fields(nested)
      |> names_only()
      |> Enum.map(&field_or_relationship(resource, &1))
      |> Enum.filter(& &1)
      |> names_only()

    case query_or_changeset do
      %Ash.Query{} = query ->
        query |> Ash.Query.select(subfields)

      %Ash.Changeset{} = changeset ->
        changeset |> Ash.Changeset.select(subfields)
    end
  end

  defp field_or_relationship(resource, identifier) do
    case Ash.Resource.Info.attribute(resource, identifier) do
      nil ->
        case Ash.Resource.Info.relationship(resource, identifier) do
          nil ->
            nil

          rel ->
            Ash.Resource.Info.attribute(resource, rel.source_attribute)
        end

      attr ->
        attr
    end
  end

  defp fields(resolution, []) do
    resolution
    |> Absinthe.Resolution.project()
  end

  defp fields(resolution, names) do
    project =
      resolution
      |> Absinthe.Resolution.project()

    Enum.reduce(names, {project, resolution.fields_cache}, fn name, {fields, cache} ->
      case fields |> Enum.find(&(&1.name == name)) do
        nil ->
          {fields, cache}

        path ->
          type = Absinthe.Schema.lookup_type(resolution.schema, path.schema_node.type)

          path
          |> Map.get(:selections)
          |> Absinthe.Resolution.Projector.project(
            type,
            resolution.path ++ [path],
            cache,
            resolution
          )
      end
    end)
    |> elem(0)
  end

  defp names_only(fields) do
    Enum.map(fields, fn
      %{schema_node: %{identifier: identifier}} ->
        identifier

      %{name: name} ->
        name
    end)
  end

  defp set_query_arguments(query, action, arg_values) do
    action = Ash.Resource.Info.action(query.resource, action)

    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.reduce(query, fn argument, query ->
      case Map.fetch(arg_values, argument.name) do
        {:ok, value} ->
          Ash.Query.set_argument(query, argument.name, value)

        _ ->
          query
      end
    end)
  end

  defp destroy_opts(api, context, action) do
    if AshGraphql.Api.Info.authorize?(api) do
      [
        actor: Map.get(context, :actor),
        action: action,
        verbose?: AshGraphql.Api.Info.debug?(api),
        stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
      ]
    else
      [
        action: action,
        verbose?: AshGraphql.Api.Info.debug?(api),
        stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
      ]
    end
  end

  defp add_root_errors(resolution, api, {:error, error_or_errors}) do
    do_root_errors(api, resolution, error_or_errors)
  end

  defp add_root_errors(resolution, api, [_, {:error, error_or_errors}]) do
    do_root_errors(api, resolution, error_or_errors)
  end

  defp add_root_errors(resolution, api, [_, {:ok, %{errors: errors}}])
       when errors not in [nil, []] do
    do_root_errors(api, resolution, errors, false)
  end

  defp add_root_errors(resolution, api, {:ok, %{errors: errors}})
       when errors not in [nil, []] do
    do_root_errors(api, resolution, errors, false)
  end

  defp add_root_errors(resolution, _api, _other_thing) do
    resolution
  end

  defp do_root_errors(api, resolution, error_or_errors, to_errors? \\ true) do
    if AshGraphql.Api.Info.root_level_errors?(api) do
      Map.update!(resolution, :errors, fn current_errors ->
        if to_errors? do
          Enum.concat(current_errors || [], List.wrap(to_errors(error_or_errors)))
        else
          Enum.concat(current_errors || [], List.wrap(error_or_errors))
        end
      end)
    else
      resolution
    end
  end

  defp add_metadata(result, action_result, action) do
    metadata = Map.get(action, :metadata, [])

    if Enum.empty?(metadata) do
      result
    else
      metadata =
        Map.new(action.metadata, fn metadata ->
          {metadata.name, Map.get(action_result.__metadata__ || %{}, metadata.name)}
        end)

      Map.put(result, :metadata, metadata)
    end
  end

  defp destroy_result(result, initial, resource, changeset, resolution) do
    case result do
      :ok ->
        {{:ok, %{result: clear_fields(initial, resource, resolution), errors: []}},
         [changeset, :ok]}

      {:error, %{changeset: changeset} = error} ->
        {{:ok, %{result: nil, errors: to_errors(changeset.errors)}}, {:error, error}}
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
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
              )

            error ->
              Logger.warn(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error)}"
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

  def resolve_calculation(
        %{source: parent, arguments: args, context: %{loader: loader} = context} = resolution,
        {api, _resource, calculation}
      ) do
    api_opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.Info.authorize?(api),
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
    ]

    opts = [
      api_opts: api_opts,
      type: :calculation,
      args: args,
      tenant: Map.get(context, :tenant)
    ]

    batch_key = {calculation.name, opts}

    do_dataloader(resolution, loader, api, batch_key, opts, parent)
  end

  def resolve_assoc(
        %{source: parent, arguments: args, context: %{loader: loader} = context} = resolution,
        {api, relationship}
      ) do
    api_opts = [
      actor: Map.get(context, :actor),
      authorize?: AshGraphql.Api.Info.authorize?(api),
      verbose?: AshGraphql.Api.Info.debug?(api),
      stacktraces?: AshGraphql.Api.Info.debug?(api) || AshGraphql.Api.Info.stacktraces?(api)
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
          type: :relationship,
          args: args,
          resource: relationship.source,
          tenant: Map.get(context, :tenant)
        ]

        batch_key = {relationship.name, opts}
        do_dataloader(resolution, loader, api, batch_key, args, parent)

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, to_resolution({:error, error}))
    end
  end

  def resolve_id(
        %{source: parent} = resolution,
        {_resource, field}
      ) do
    Absinthe.Resolution.put_result(resolution, {:ok, Map.get(parent, field)})
  end

  def resolve_composite_id(
        %{source: parent} = resolution,
        {_resource, _fields}
      ) do
    Absinthe.Resolution.put_result(
      resolution,
      {:ok, AshGraphql.Resource.encode_primary_key(parent)}
    )
  end

  def query_complexity(
        %{limit: limit},
        child_complexity,
        _
      ) do
    if child_complexity == 0 do
      1
    else
      limit * child_complexity
    end
  end

  def query_complexity(
        _,
        child_complexity,
        _
      ) do
    child_complexity + 1
  end

  def fetch_dataloader(loader, api, batch_key, parent) do
    to_resolution(Dataloader.get(loader, api, batch_key, parent))
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
      fetch_dataloader(loader, api, batch_key, parent)
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
           "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
         )

         [
           message: "Something went wrong. Unique error id: `#{uuid}`"
         ]
       end
     end)}
  end
end
