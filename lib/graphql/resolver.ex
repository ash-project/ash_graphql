defmodule AshGraphql.Graphql.Resolver do
  @moduledoc false

  require Logger
  import Ash.Expr
  import AshGraphql.TraceHelpers
  import AshGraphql.ContextHelpers

  def resolve(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {domain, resource, %AshGraphql.Resource.Action{name: query_name, action: action}, input?}
      ) do
    arguments =
      if input? do
        arguments[:input] || %{}
      else
        arguments
      end

    action = Ash.Resource.Info.action(resource, action)

    case handle_arguments(resource, action, arguments) do
      {:ok, arguments} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          source: :graphql,
          query: query_name,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_query,
              query_name,
              metadata do
          opts = [
            actor: Map.get(context, :actor),
            authorize?: AshGraphql.Domain.Info.authorize?(domain),
            tenant: Map.get(context, :tenant)
          ]

          result =
            %Ash.ActionInput{domain: domain, resource: resource}
            |> Ash.ActionInput.set_context(get_context(context))
            |> Ash.ActionInput.for_action(action.name, arguments)
            |> domain.run_action(opts)
            |> case do
              {:ok, result} ->
                load_opts =
                  [
                    actor: Map.get(context, :actor),
                    action: action,
                    domain: domain,
                    authorize?: AshGraphql.Domain.Info.authorize?(domain),
                    tenant: Map.get(context, :tenant)
                  ]

                if Ash.Type.can_load?(action.returns, action.constraints) do
                  {fields, path} = nested_fields_and_path(resolution, [], [])

                  loads =
                    type_loads(
                      fields,
                      context,
                      action.returns,
                      action.constraints,
                      load_opts,
                      resource,
                      action.name,
                      resolution,
                      path,
                      hd(resolution.path),
                      nil
                    )

                  case loads do
                    [] ->
                      {:ok, result}

                    loads ->
                      Ash.Type.load(
                        action.returns,
                        result,
                        loads,
                        action.constraints,
                        Map.new(load_opts)
                      )
                  end
                else
                  {:ok, result}
                end

              {:error, error} ->
                {:error, error}
            end

          resolution
          |> Absinthe.Resolution.put_result(
            to_resolution(
              result,
              context,
              domain
            )
          )
          |> add_root_errors(domain, result)
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        Absinthe.Resolution.put_result(
          resolution,
          to_resolution({:error, error}, context, domain)
        )
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  def resolve(
        %{arguments: arguments, context: context} = resolution,
        {domain, resource,
         %{
           name: query_name,
           type: :get,
           action: action,
           identity: identity,
           type_name: type_name,
           modify_resolution: modify
         } = gql_query, relay_ids?}
      ) do
    case handle_arguments(resource, action, arguments) do
      {:ok, arguments} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          source: :graphql,
          query: query_name,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_query,
              query_name,
              metadata do
          opts = [
            actor: Map.get(context, :actor),
            action: action,
            authorize?: AshGraphql.Domain.Info.authorize?(domain),
            tenant: Map.get(context, :tenant)
          ]

          filter = identity_filter(identity, resource, arguments, relay_ids?)

          query =
            resource
            |> Ash.Query.new()
            |> Ash.Query.set_tenant(Map.get(context, :tenant))
            |> Ash.Query.set_context(get_context(context))
            |> set_query_arguments(action, arguments)
            |> select_fields(resource, resolution, type_name)

          {result, modify_args} =
            case filter do
              {:ok, filter} ->
                query =
                  query
                  |> Ash.Query.do_filter(filter)
                  |> load_fields(
                    [
                      domain: domain,
                      tenant: Map.get(context, :tenant),
                      authorize?: AshGraphql.Domain.Info.authorize?(domain),
                      tracer: AshGraphql.Domain.Info.tracer(domain),
                      actor: Map.get(context, :actor)
                    ],
                    resource,
                    resolution,
                    resolution.path,
                    context
                  )

                result =
                  query
                  |> Ash.Query.for_read(action, %{},
                    actor: opts[:actor],
                    authorize?: AshGraphql.Domain.Info.authorize?(domain)
                  )
                  |> domain.read_one(opts)

                {result, [query, result]}

              {:error, error} ->
                query =
                  resource
                  |> Ash.Query.new()
                  |> Ash.Query.set_tenant(Map.get(context, :tenant))
                  |> Ash.Query.set_context(get_context(context))
                  |> set_query_arguments(action, arguments)
                  |> select_fields(resource, resolution, type_name)
                  |> load_fields(
                    [
                      domain: domain,
                      tenant: Map.get(context, :tenant),
                      authorize?: AshGraphql.Domain.Info.authorize?(domain),
                      tracer: AshGraphql.Domain.Info.tracer(domain),
                      actor: Map.get(context, :actor)
                    ],
                    resource,
                    resolution,
                    resolution.path,
                    context
                  )

                {{:error, error}, [query, {:error, error}]}
            end

          case {result, gql_query.allow_nil?} do
            {{:ok, nil}, false} ->
              {:ok, filter} = filter

              error =
                Ash.Error.Query.NotFound.exception(
                  primary_key: Map.new(filter || []),
                  resource: resource
                )

              resolution
              |> Absinthe.Resolution.put_result({:error, to_errors([error], context, domain)})
              |> add_root_errors(domain, result)

            {result, _} ->
              resolution
              |> Absinthe.Resolution.put_result(
                to_resolution(
                  result
                  |> add_read_metadata(
                    gql_query,
                    Ash.Resource.Info.action(query.resource, action)
                  ),
                  context,
                  domain
                )
              )
              |> add_root_errors(domain, result)
              |> modify_resolution(modify, modify_args)
          end
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        Absinthe.Resolution.put_result(
          resolution,
          to_resolution({:error, error}, context, domain)
        )
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {domain, resource,
         %{
           name: query_name,
           type: :read_one,
           action: action,
           modify_resolution: modify,
           type_name: type_name
         } =
           gql_query, _relay_ids?}
      ) do
    metadata = %{
      domain: domain,
      resource: resource,
      resource_short_name: Ash.Resource.Info.short_name(resource),
      actor: Map.get(context, :actor),
      tenant: Map.get(context, :tenant),
      action: action,
      source: :graphql,
      query: query_name,
      authorize?: AshGraphql.Domain.Info.authorize?(domain)
    }

    with {:ok, args} <- handle_arguments(resource, action, args),
         {:ok, query} <- read_one_query(resource, args) do
      trace domain,
            resource,
            :gql_query,
            query_name,
            metadata do
        opts = [
          actor: Map.get(context, :actor),
          action: action,
          authorize?: AshGraphql.Domain.Info.authorize?(domain),
          tenant: Map.get(context, :tenant)
        ]

        query =
          query
          |> Ash.Query.set_tenant(Map.get(context, :tenant))
          |> Ash.Query.set_context(get_context(context))
          |> set_query_arguments(action, args)
          |> select_fields(resource, resolution, type_name)
          |> load_fields(
            [
              domain: domain,
              tenant: Map.get(context, :tenant),
              authorize?: AshGraphql.Domain.Info.authorize?(domain),
              tracer: AshGraphql.Domain.Info.tracer(domain),
              actor: Map.get(context, :actor)
            ],
            resource,
            resolution,
            resolution.path,
            context
          )

        result =
          query
          |> Ash.Query.for_read(action, %{},
            actor: opts[:actor],
            authorize?: AshGraphql.Domain.Info.authorize?(domain)
          )
          |> domain.read_one(opts)

        result =
          add_read_metadata(
            result,
            gql_query,
            Ash.Resource.Info.action(query.resource, action)
          )

        resolution
        |> Absinthe.Resolution.put_result(to_resolution(result, context, domain))
        |> add_root_errors(domain, result)
        |> modify_resolution(modify, [query, args])
      end
    else
      {:error, error} ->
        resolution
        |> Absinthe.Resolution.put_result(to_resolution({:error, error}, context, domain))
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        Absinthe.Resolution.put_result(
          resolution,
          to_resolution({:error, error}, context, domain)
        )
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  def resolve(
        %{arguments: args, context: context} = resolution,
        {domain, resource,
         %{
           name: query_name,
           type: :list,
           relay?: relay?,
           action: action,
           type_name: type_name,
           modify_resolution: modify
         } = gql_query, _relay_ids?}
      ) do
    case handle_arguments(resource, action, args) do
      {:ok, args} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          source: :graphql,
          query: query_name,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_query,
              query_name,
              metadata do
          opts = [
            actor: Map.get(context, :actor),
            action: action,
            authorize?: AshGraphql.Domain.Info.authorize?(domain),
            tenant: Map.get(context, :tenant)
          ]

          pagination = Ash.Resource.Info.action(resource, action).pagination
          query = apply_load_arguments(args, Ash.Query.new(resource), true)

          {result, modify_args} =
            with {:ok, opts} <-
                   validate_resolve_opts(resolution, resource, pagination, relay?, opts, args),
                 result_fields <- get_result_fields(pagination, relay?),
                 initial_query <-
                   query
                   |> Ash.Query.set_tenant(Map.get(context, :tenant))
                   |> Ash.Query.set_context(get_context(context))
                   |> set_query_arguments(action, args)
                   |> select_fields(resource, resolution, type_name, result_fields),
                 query <-
                   load_fields(
                     initial_query,
                     [
                       domain: domain,
                       tenant: Map.get(context, :tenant),
                       authorize?: AshGraphql.Domain.Info.authorize?(domain),
                       tracer: AshGraphql.Domain.Info.tracer(domain),
                       actor: Map.get(context, :actor)
                     ],
                     resource,
                     resolution,
                     resolution.path,
                     context,
                     result_fields
                   ),
                 {:ok, page} <-
                   query
                   |> Ash.Query.for_read(action, %{},
                     actor: Map.get(context, :actor),
                     authorize?: AshGraphql.Domain.Info.authorize?(domain)
                   )
                   |> domain.read(opts) do
              result = paginate(resource, action, page, relay?)
              {result, [query, result]}
            else
              {:error, error} ->
                {{:error, error}, [query, {:error, error}]}
            end

          result =
            add_read_metadata(result, gql_query, Ash.Resource.Info.action(query.resource, action))

          resolution
          |> Absinthe.Resolution.put_result(to_resolution(result, context, domain))
          |> add_root_errors(domain, modify_args)
          |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        Absinthe.Resolution.put_result(
          resolution,
          to_resolution({:error, error}, context, domain)
        )
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  defp read_one_query(resource, args) do
    case Map.fetch(args, :filter) do
      {:ok, filter} when filter != %{} ->
        case Ash.Filter.parse_input(resource, filter) do
          {:ok, parsed} ->
            {:ok, Ash.Query.do_filter(resource, parsed)}

          {:error, error} ->
            {:error, error}
        end

      _ ->
        {:ok, Ash.Query.new(resource)}
    end
  end

  defp handle_arguments(_resource, nil, argument_values) do
    {:ok, argument_values}
  end

  defp handle_arguments(resource, action, argument_values) when is_atom(action) do
    action = Ash.Resource.Info.action(resource, action)
    handle_arguments(resource, action, argument_values)
  end

  defp handle_arguments(resource, action, argument_values) do
    action_arguments = action.arguments

    attributes =
      resource
      |> Ash.Resource.Info.attributes()

    argument_values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, arguments} ->
      argument =
        Enum.find(action_arguments, &(&1.name == key)) || Enum.find(attributes, &(&1.name == key))

      if argument do
        %{type: type, name: name, constraints: constraints} = argument

        case handle_argument(resource, action, type, constraints, value, name) do
          {:ok, value} ->
            {:cont, {:ok, Map.put(arguments, name, value)}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      else
        {:cont, {:ok, Map.put(arguments, key, value)}}
      end
    end)
  end

  defp handle_argument(resource, action, {:array, type}, constraints, value, name)
       when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case handle_argument(resource, action, type, constraints[:items], value, name) do
        {:ok, value} ->
          {:cont, {:ok, [value | acc]}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, value} -> {:ok, Enum.reverse(value)}
      {:error, error} -> {:error, error}
    end
  end

  defp handle_argument(_resource, _action, Ash.Type.Union, constraints, value, name) do
    handle_union_type(value, constraints, name)
  end

  defp handle_argument(resource, action, type, constraints, value, name) do
    cond do
      AshGraphql.Resource.Info.managed_relationship(resource, action, %{name: name}) &&
          is_map(value) ->
        managed_relationship =
          AshGraphql.Resource.Info.managed_relationship(resource, action, %{name: name})

        opts = AshGraphql.Resource.find_manage_change(%{name: name}, action, resource)

        relationship =
          Ash.Resource.Info.relationship(resource, opts[:relationship]) ||
            raise """
            No relationship found when building managed relationship input: #{opts[:relationship]}
            """

        manage_opts_schema =
          if opts[:opts][:type] do
            defaults = Ash.Changeset.manage_relationship_opts(opts[:opts][:type])

            Enum.reduce(defaults, Ash.Changeset.manage_relationship_schema(), fn {key, value},
                                                                                 manage_opts ->
              Spark.Options.Helpers.set_default!(manage_opts, key, value)
            end)
          else
            Ash.Changeset.manage_relationship_schema()
          end

        manage_opts = Spark.Options.validate!(opts[:opts], manage_opts_schema)

        fields =
          manage_opts
          |> AshGraphql.Resource.manage_fields(
            managed_relationship,
            relationship,
            __MODULE__
          )
          |> Enum.reject(fn
            {_, :__primary_key, _} ->
              true

            {_, {:identity, _}, _} ->
              true

            _ ->
              false
          end)
          |> Map.new(fn {_, _, %{identifier: identifier}} = field ->
            {identifier, field}
          end)

        Enum.reduce_while(value, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
          field_name =
            resource
            |> AshGraphql.Resource.Info.field_names()
            |> Enum.map(fn {l, r} -> {r, l} end)
            |> Keyword.get(key, key)

          case Map.get(fields, field_name) do
            nil ->
              {:cont, {:ok, Map.put(acc, key, value)}}

            {resource, action, _} ->
              action = Ash.Resource.Info.action(resource, action)
              attributes = Ash.Resource.Info.public_attributes(resource)

              argument =
                Enum.find(action.arguments, &(&1.name == field_name)) ||
                  Enum.find(attributes, &(&1.name == field_name))

              if argument do
                %{type: type, name: name, constraints: constraints} = argument

                case handle_argument(resource, action, type, constraints, value, name) do
                  {:ok, value} ->
                    {:cont, {:ok, Map.put(acc, key, value)}}

                  {:error, error} ->
                    {:halt, {:error, error}}
                end
              else
                {:cont, {:ok, Map.put(acc, key, value)}}
              end
          end
        end)

      Ash.Type.NewType.new_type?(type) ->
        handle_argument(
          resource,
          action,
          Ash.Type.NewType.subtype_of(type),
          Ash.Type.NewType.constraints(type, constraints),
          value,
          name
        )

      AshGraphql.Resource.embedded?(type) and is_map(value) ->
        create_action =
          if constraints[:create_action] do
            Ash.Resource.Info.action(type, constraints[:create_action]) ||
              Ash.Resource.Info.primary_action(type, :create)
          else
            Ash.Resource.Info.primary_action(type, :create)
          end

        update_action =
          if constraints[:update_action] do
            Ash.Resource.Info.action(type, constraints[:update_action]) ||
              Ash.Resource.Info.primary_action(type, :update)
          else
            Ash.Resource.Info.primary_action(type, :update)
          end

        attributes = Ash.Resource.Info.public_attributes(type)

        fields =
          cond do
            create_action && update_action ->
              create_action.arguments ++ update_action.arguments ++ attributes

            update_action ->
              update_action.arguments ++ attributes

            create_action ->
              create_action.arguments ++ attributes

            true ->
              attributes
          end

        value
        |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
          field =
            Enum.find(fields, fn field ->
              field.name == key
            end)

          if field do
            case handle_argument(
                   resource,
                   action,
                   field.type,
                   field.constraints,
                   value,
                   "#{name}.#{key}"
                 ) do
              {:ok, value} ->
                {:cont, {:ok, Map.put(acc, key, value)}}

              {:error, error} ->
                {:halt, {:error, error}}
            end
          else
            {:cont, {:ok, Map.put(acc, key, value)}}
          end
        end)

      true ->
        {:ok, value}
    end
  end

  defp handle_union_type(value, constraints, name) do
    value
    |> Enum.reject(fn {_key, value} ->
      is_nil(value)
    end)
    |> case do
      [] ->
        {:ok, nil}

      [{key, value}] ->
        config = constraints[:types][key]

        if config[:tag] && is_map(value) do
          {:ok, Map.put_new(value, config[:tag], config[:tag_value])}
        else
          {:ok, value}
        end

      key_vals ->
        keys = Enum.map_join(key_vals, ", ", fn {key, _} -> to_string(key) end)

        {:error,
         %{message: "Only one key can be specified, but got #{keys}", fields: ["#{name}"]}}
    end
  end

  def validate_resolve_opts(resolution, resource, pagination, relay?, opts, args) do
    if pagination && (pagination.offset? || pagination.keyset?) do
      with page_opts <-
             args
             |> Map.take([:limit, :offset, :first, :after, :before, :last])
             |> Enum.reject(fn {_, val} -> is_nil(val) end),
           {:ok, page_opts} <- validate_offset_opts(page_opts, pagination),
           {:ok, page_opts} <- validate_keyset_opts(page_opts, pagination) do
        type = page_type(resource, pagination, relay?)
        field_names = resolution |> fields([], type) |> names_only()

        page =
          if Enum.any?(field_names, &(&1 == :count)) do
            Keyword.put(page_opts, :count, true)
          else
            page_opts
          end

        {:ok, Keyword.put(opts, :page, page)}
      else
        error ->
          error
      end
    else
      {:ok, opts}
    end
  end

  defp validate_offset_opts(opts, %{offset?: true, max_page_size: max_page_size}) do
    limit =
      case opts |> Keyword.take([:limit]) |> Enum.into(%{}) do
        %{limit: limit} ->
          min(limit, max_page_size)

        _ ->
          max_page_size
      end

    {:ok, Keyword.put(opts, :limit, limit)}
  end

  defp validate_offset_opts(opts, _) do
    {:ok, opts}
  end

  defp validate_keyset_opts(opts, %{keyset?: true, max_page_size: max_page_size}) do
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

  defp validate_keyset_opts(opts, _) do
    {:ok, opts}
  end

  defp get_result_fields(%{keyset?: true}, true) do
    ["edges", "node"]
  end

  defp get_result_fields(%{keyset?: true}, false) do
    ["results"]
  end

  defp get_result_fields(%{offset?: true}, _) do
    ["results"]
  end

  defp get_result_fields(_pagination, _) do
    []
  end

  defp paginate(
         _resource,
         _action,
         %Ash.Page.Keyset{
           results: results,
           more?: more,
           after: after_cursor,
           before: before_cursor,
           count: count
         },
         relay?
       ) do
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

    if relay? do
      {
        :ok,
        %{
          page_info: %{
            start_cursor: start_cursor,
            end_cursor: end_cursor,
            has_next_page: has_next_page,
            has_previous_page: has_previous_page
          },
          count: count,
          edges:
            Enum.map(results, fn result ->
              %{
                cursor: result.__metadata__.keyset,
                node: result
              }
            end)
        }
      }
    else
      {:ok, %{results: results, count: count, start_keyset: start_cursor, end_keyset: end_cursor}}
    end
  end

  defp paginate(
         _resource,
         _action,
         %Ash.Page.Offset{results: results, count: count, more?: more},
         true
       ) do
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

    has_previous_page = false
    has_next_page = more

    {
      :ok,
      %{
        page_info: %{
          start_cursor: start_cursor,
          end_cursor: end_cursor,
          has_next_page: has_next_page,
          has_previous_page: has_previous_page
        },
        count: count,
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

  defp paginate(
         _resource,
         _action,
         %Ash.Page.Offset{results: results, count: count, more?: more?},
         _
       ) do
    {:ok, %{results: results, count: count, more?: more?}}
  end

  defp paginate(resource, action, page, relay?) do
    case Ash.Resource.Info.action(resource, action).pagination do
      %{offset?: true} ->
        paginate(
          resource,
          action,
          %Ash.Page.Offset{results: page, count: Enum.count(page), more?: false},
          relay?
        )

      %{keyset?: true} ->
        paginate(
          resource,
          action,
          %Ash.Page.Keyset{
            results: page,
            more?: false,
            after: nil,
            before: nil
          },
          relay?
        )

      _ ->
        {:ok, page}
    end
  end

  def mutate(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {domain, resource,
         %{
           type: :create,
           name: mutation_name,
           action: action,
           upsert?: upsert?,
           upsert_identity: upsert_identity,
           modify_resolution: modify
         }, _relay_ids?}
      ) do
    input = arguments[:input] || %{}

    case handle_arguments(resource, action, input) do
      {:ok, input} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          source: :graphql,
          mutation_name: mutation_name,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_mutation,
              mutation_name,
              metadata do
          opts = [
            actor: Map.get(context, :actor),
            action: action,
            authorize?: AshGraphql.Domain.Info.authorize?(domain),
            tenant: Map.get(context, :tenant),
            upsert?: upsert?
          ]

          opts =
            if upsert? && upsert_identity do
              Keyword.put(opts, :upsert_identity, upsert_identity)
            else
              opts
            end

          type_name = mutation_result_type(mutation_name)

          changeset =
            resource
            |> Ash.Changeset.new()
            |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
            |> Ash.Changeset.set_context(get_context(context))
            |> Ash.Changeset.for_create(action, input,
              actor: Map.get(context, :actor),
              authorize?: AshGraphql.Domain.Info.authorize?(domain)
            )
            |> select_fields(resource, resolution, type_name, ["result"])
            |> load_fields(
              [
                domain: domain,
                tenant: Map.get(context, :tenant),
                authorize?: AshGraphql.Domain.Info.authorize?(domain),
                tracer: AshGraphql.Domain.Info.tracer(domain),
                actor: Map.get(context, :actor)
              ],
              resource,
              resolution,
              resolution.path,
              context,
              ["result"]
            )

          {result, modify_args} =
            changeset
            |> domain.create(opts)
            |> case do
              {:ok, value} ->
                {{:ok, add_metadata(%{result: value, errors: []}, value, changeset.action)},
                 [changeset, {:ok, value}]}

              {:error, %{changeset: changeset} = error} ->
                {{:ok, %{result: nil, errors: to_errors(changeset.errors, context, domain)}},
                 [changeset, {:error, error}]}
            end

          resolution
          |> Absinthe.Resolution.put_result(to_resolution(result, context, domain))
          |> add_root_errors(domain, modify_args)
          |> modify_resolution(modify, modify_args)
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Domain.Info.root_level_errors?(domain) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error}, context, domain)
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution(
              {:ok, %{result: nil, errors: to_errors(error, context, domain)}},
              context,
              domain
            )
          )
        end
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {domain, resource,
         %{
           name: mutation_name,
           type: :update,
           action: action,
           identity: identity,
           read_action: read_action,
           modify_resolution: modify
         }, relay_ids?}
      ) do
    read_action = read_action || Ash.Resource.Info.primary_action!(resource, :read).name
    input = arguments[:input] || %{}

    args_result =
      with {:ok, input} <- handle_arguments(resource, action, input),
           {:ok, read_action_input} <-
             handle_arguments(resource, read_action, Map.delete(arguments, :input)) do
        {:ok, input, read_action_input}
      end

    case args_result do
      {:ok, input, read_action_input} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          mutation: mutation_name,
          source: :graphql,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_mutation,
              mutation_name,
              metadata do
          filter = identity_filter(identity, resource, arguments, relay_ids?)

          case filter do
            {:ok, filter} ->
              resource
              |> Ash.Query.do_filter(filter)
              |> Ash.Query.set_tenant(Map.get(context, :tenant))
              |> Ash.Query.set_context(get_context(context))
              |> set_query_arguments(read_action, read_action_input)
              |> domain.read_one(
                action: read_action,
                actor: Map.get(context, :actor),
                authorize?: AshGraphql.Domain.Info.authorize?(domain)
              )
              |> case do
                {:ok, nil} ->
                  result = not_found(filter, resource, context, domain)

                  resolution
                  |> Absinthe.Resolution.put_result(result)
                  |> add_root_errors(domain, result)

                {:ok, initial} ->
                  opts = [
                    actor: Map.get(context, :actor),
                    action: action,
                    authorize?: AshGraphql.Domain.Info.authorize?(domain),
                    tenant: Map.get(context, :tenant)
                  ]

                  type_name = mutation_result_type(mutation_name)

                  changeset =
                    initial
                    |> Ash.Changeset.new()
                    |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
                    |> Ash.Changeset.set_context(get_context(context))
                    |> Ash.Changeset.for_update(action, input,
                      actor: Map.get(context, :actor),
                      authorize?: AshGraphql.Domain.Info.authorize?(domain)
                    )
                    |> select_fields(resource, resolution, type_name, ["result"])
                    |> load_fields(
                      [
                        domain: domain,
                        tenant: Map.get(context, :tenant),
                        authorize?: AshGraphql.Domain.Info.authorize?(domain),
                        tracer: AshGraphql.Domain.Info.tracer(domain),
                        actor: Map.get(context, :actor)
                      ],
                      resource,
                      resolution,
                      resolution.path,
                      context,
                      ["result"]
                    )

                  {result, modify_args} =
                    changeset
                    |> domain.update(opts)
                    |> case do
                      {:ok, value} ->
                        {{:ok,
                          add_metadata(%{result: value, errors: []}, value, changeset.action)},
                         [changeset, {:ok, value}]}

                      {:error, error} ->
                        {{:ok,
                          %{result: nil, errors: to_errors(List.wrap(error), context, domain)}},
                         [changeset, {:error, error}]}
                    end

                  resolution
                  |> Absinthe.Resolution.put_result(to_resolution(result, context, domain))
                  |> add_root_errors(domain, modify_args)
                  |> modify_resolution(modify, modify_args)

                {:error, error} ->
                  Absinthe.Resolution.put_result(
                    resolution,
                    to_resolution({:error, error}, context, domain)
                  )
              end

            {:error, error} ->
              Absinthe.Resolution.put_result(
                resolution,
                to_resolution({:error, error}, context, domain)
              )
          end
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Domain.Info.root_level_errors?(domain) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error}, context, domain)
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution(
              {:ok, %{result: nil, errors: to_errors(error, context, domain)}},
              context,
              domain
            )
          )
        end
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  def mutate(
        %{arguments: arguments, context: context} = resolution,
        {domain, resource,
         %{
           name: mutation_name,
           type: :destroy,
           action: action,
           identity: identity,
           read_action: read_action,
           modify_resolution: modify
         }, relay_ids?}
      ) do
    read_action = read_action || Ash.Resource.Info.primary_action!(resource, :read).name
    input = arguments[:input] || %{}

    args_result =
      with {:ok, input} <- handle_arguments(resource, action, input),
           {:ok, read_action_input} <-
             handle_arguments(resource, read_action, Map.delete(arguments, :input)) do
        {:ok, input, read_action_input}
      end

    case args_result do
      {:ok, input, read_action_input} ->
        metadata = %{
          domain: domain,
          resource: resource,
          resource_short_name: Ash.Resource.Info.short_name(resource),
          actor: Map.get(context, :actor),
          tenant: Map.get(context, :tenant),
          action: action,
          source: :graphql,
          mutation: mutation_name,
          authorize?: AshGraphql.Domain.Info.authorize?(domain)
        }

        trace domain,
              resource,
              :gql_mutation,
              mutation_name,
              metadata do
          filter = identity_filter(identity, resource, arguments, relay_ids?)

          case filter do
            {:ok, filter} ->
              resource
              |> Ash.Query.do_filter(filter)
              |> Ash.Query.set_tenant(Map.get(context, :tenant))
              |> Ash.Query.set_context(get_context(context))
              |> set_query_arguments(action, read_action_input)
              |> domain.read_one(
                action: read_action,
                actor: Map.get(context, :actor),
                authorize?: AshGraphql.Domain.Info.authorize?(domain)
              )
              |> case do
                {:ok, nil} ->
                  result = not_found(filter, resource, context, domain)

                  resolution
                  |> Absinthe.Resolution.put_result(result)
                  |> add_root_errors(domain, result)

                {:ok, initial} ->
                  opts = [
                    action: action,
                    actor: Map.get(context, :actor),
                    authorize?: AshGraphql.Domain.Info.authorize?(domain),
                    tenant: Map.get(context, :tenant)
                  ]

                  type_name = mutation_result_type(mutation_name)

                  changeset =
                    initial
                    |> Ash.Changeset.new()
                    |> Ash.Changeset.set_tenant(Map.get(context, :tenant))
                    |> Ash.Changeset.set_context(get_context(context))
                    |> Ash.Changeset.for_destroy(action, input,
                      actor: Map.get(context, :actor),
                      authorize?: AshGraphql.Domain.Info.authorize?(domain)
                    )
                    |> select_fields(resource, resolution, type_name, ["result"])

                  {result, modify_args} =
                    changeset
                    |> domain.destroy(opts)
                    |> destroy_result(initial, resource, changeset, domain, resolution)

                  resolution
                  |> Absinthe.Resolution.put_result(to_resolution(result, context, domain))
                  |> add_root_errors(domain, result)
                  |> modify_resolution(modify, modify_args)

                {:error, error} ->
                  Absinthe.Resolution.put_result(
                    resolution,
                    to_resolution({:error, error}, context, domain)
                  )
              end

            {:error, error} ->
              Absinthe.Resolution.put_result(
                resolution,
                to_resolution({:error, error}, context, domain)
              )
          end
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      if AshGraphql.Domain.Info.show_raised_errors?(domain) do
        error = Ash.Error.to_ash_error([e], __STACKTRACE__)

        if AshGraphql.Domain.Info.root_level_errors?(domain) do
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution({:error, error}, context, domain)
          )
        else
          Absinthe.Resolution.put_result(
            resolution,
            to_resolution(
              {:ok, %{result: nil, errors: to_errors(error, context, domain)}},
              context,
              domain
            )
          )
        end
      else
        something_went_wrong(resolution, e, domain, __STACKTRACE__)
      end
  end

  defp log_exception(e, stacktrace) do
    uuid = Ash.UUID.generate()

    Logger.error("""
    #{uuid}: Exception raised while resolving query.

    #{String.slice(Exception.format(:error, e), 0, 2000)}

    #{Exception.format_stacktrace(stacktrace)}
    """)

    uuid
  end

  defp something_went_wrong(resolution, e, domain, stacktrace) do
    tracer = AshGraphql.Domain.Info.tracer(domain)

    Ash.Tracer.set_error(tracer, e)

    uuid = log_exception(e, stacktrace)

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

  def identity_filter(false, _resource, _arguments, _relay_ids?) do
    {:ok, nil}
  end

  def identity_filter(nil, resource, arguments, relay_ids?) do
    if relay_ids? or AshGraphql.Resource.Info.encode_primary_key?(resource) do
      case AshGraphql.Resource.decode_id(
             resource,
             Map.get(arguments, :id) || "",
             relay_ids?
           ) do
        {:ok, value} ->
          {:ok, value}

        {:error, error} ->
          {:error, error}
      end
    else
      resource
      |> Ash.Resource.Info.primary_key()
      |> Enum.reduce_while({:ok, nil}, fn key, {:ok, expr} ->
        value = Map.get(arguments, key)

        if value do
          if expr do
            {:cont, {:ok, Ash.Expr.expr(^expr and ^ref(key) == ^value)}}
          else
            {:cont, {:ok, Ash.Expr.expr(^ref(key) == ^value)}}
          end
        else
          {:halt, {:error, "Required key not present"}}
        end
      end)
    end
  end

  def identity_filter(identity, resource, arguments, _relay_ids?) do
    {:ok,
     resource
     |> Ash.Resource.Info.identities()
     |> Enum.find(&(&1.name == identity))
     |> Map.get(:keys)
     |> Enum.map(fn key ->
       {key, Map.get(arguments, key)}
     end)}
  end

  defp not_found(filter, resource, context, domain) do
    {:ok,
     %{
       result: nil,
       errors:
         to_errors(
           Ash.Error.Query.NotFound.exception(
             primary_key: Map.new(filter || []),
             resource: resource
           ),
           context,
           domain
         )
     }}
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
    type = AshGraphql.Resource.Info.type(resource)

    resolution
    |> fields(["result"], type)
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

  @doc false
  def load_fields(
        query_or_changeset,
        load_opts,
        resource,
        resolution,
        path,
        context,
        nested \\ []
      ) do
    {fields, path} = nested_fields_and_path(resolution, path, nested)

    fields
    |> resource_loads(resource, resolution, load_opts, path, context)
    |> then(fn load ->
      case query_or_changeset do
        %Ash.Query{} = query ->
          Ash.Query.load(query, load)

        %Ash.Changeset{} = changeset ->
          Ash.Changeset.load(changeset, load)
      end
    end)
  end

  defp nested_fields_and_path(resolution, path, []) do
    base = Enum.at(path, 0) || resolution

    selections =
      case base do
        %Absinthe.Resolution{} ->
          Absinthe.Resolution.project(resolution)

        %Absinthe.Blueprint.Document.Field{selections: selections} ->
          {fields, _} =
            selections
            |> Absinthe.Resolution.Projector.project(
              Absinthe.Schema.lookup_type(resolution.schema, base.schema_node.type),
              path,
              %{},
              resolution
            )

          fields
      end

    {selections, path}
  end

  defp nested_fields_and_path(resolution, path, [nested | rest]) do
    base = Enum.at(path, 0) || resolution

    selections =
      case base do
        %Absinthe.Resolution{} ->
          Absinthe.Resolution.project(resolution)

        %Absinthe.Blueprint.Document.Field{selections: selections} ->
          {fields, _} =
            selections
            |> Absinthe.Resolution.Projector.project(
              Absinthe.Schema.lookup_type(resolution.schema, base.schema_node.type),
              path,
              %{},
              resolution
            )

          fields
      end

    selection = Enum.find(selections, &(&1.name == nested))

    if selection do
      nested_fields_and_path(resolution, [selection | path], rest)
    else
      {[], path}
    end
  end

  defp resource_loads(fields, resource, resolution, load_opts, path, context) do
    Enum.flat_map(fields, fn selection ->
      cond do
        aggregate = Ash.Resource.Info.aggregate(resource, selection.schema_node.identifier) ->
          [aggregate.name]

        calculation = Ash.Resource.Info.calculation(resource, selection.schema_node.identifier) ->
          arguments =
            selection.arguments
            |> Map.new(fn argument ->
              {argument.schema_node.identifier, argument.input_value.data}
            end)
            |> then(fn args ->
              if selection.alias do
                Map.put(args, :as, {:__ash_graphql_calculation__, selection.alias})
              else
                args
              end
            end)

          if Ash.Type.can_load?(calculation.type, calculation.constraints) do
            loads =
              type_loads(
                selection.selections,
                context,
                calculation.type,
                calculation.constraints,
                load_opts,
                resource,
                calculation.name,
                resolution,
                [selection | path],
                selection,
                AshGraphql.Resource.Info.type(resource)
              )

            case loads do
              [] ->
                [{calculation.name, arguments}]

              loads ->
                [{calculation.name, {arguments, loads}}]
            end
          else
            [{calculation.name, arguments}]
          end

        attribute = Ash.Resource.Info.attribute(resource, selection.schema_node.identifier) ->
          if Ash.Type.can_load?(attribute.type, attribute.constraints) do
            loads =
              type_loads(
                selection.selections,
                context,
                attribute.type,
                attribute.constraints,
                load_opts,
                resource,
                attribute.name,
                resolution,
                [selection | path],
                selection,
                AshGraphql.Resource.Info.type(resource)
              )

            case loads do
              [] ->
                if selection.alias do
                  {:ok, calc} =
                    Ash.Query.Calculation.new(
                      {:__ash_graphql_attribute__, selection.alias},
                      Ash.Resource.Calculation.LoadAttribute,
                      Keyword.put(load_opts, :attribute, attribute.name),
                      attribute.type,
                      attribute.constraints
                    )

                  [
                    calc
                  ]
                else
                  [attribute.name]
                end

              loads ->
                if selection.alias do
                  {:ok, calc} =
                    Ash.Query.Calculation.new(
                      {:__ash_graphql_attribute__, selection.alias},
                      Ash.Resource.Calculation.LoadAttribute,
                      Keyword.merge(load_opts, load: loads, attribute: attribute.name),
                      attribute.type,
                      attribute.constraints
                    )

                  [
                    calc
                  ]
                else
                  [{attribute.name, loads}]
                end
            end
          else
            [attribute.name]
          end

        relationship = Ash.Resource.Info.relationship(resource, selection.schema_node.identifier) ->
          read_action =
            case relationship.read_action do
              nil ->
                Ash.Resource.Info.primary_action!(relationship.destination, :read)

              read_action ->
                Ash.Resource.Info.action(relationship.destination, read_action)
            end

          args =
            Map.new(selection.arguments, fn argument ->
              {argument.schema_node.identifier, argument.input_value.data}
            end)

          related_query =
            relationship.destination
            |> Ash.Query.new()
            |> Ash.Query.set_tenant(Map.get(context, :tenant))
            |> Ash.Query.set_context(get_context(context))

          related_query =
            args
            |> apply_load_arguments(related_query)
            |> set_query_arguments(read_action, args)
            |> select_fields(
              relationship.destination,
              resolution,
              nil,
              Enum.map(Enum.reverse([selection | path]), & &1.name)
            )
            |> load_fields(
              load_opts,
              relationship.destination,
              resolution,
              [
                selection | path
              ],
              context
            )

          if selection.alias do
            {type, constraints} =
              case relationship.cardinality do
                :many ->
                  {{:array, :struct}, items: [instance_of: relationship.destination]}

                :one ->
                  {:struct, instance_of: relationship.destination}
              end

            {:ok, calc} =
              Ash.Query.Calculation.new(
                {:__ash_graphql_relationship__, selection.alias},
                Ash.Resource.Calculation.LoadRelationship,
                Keyword.merge(load_opts, relationship: relationship.name, query: related_query),
                type,
                constraints
              )

            [
              calc
            ]
          else
            [{relationship.name, related_query}]
          end

        true ->
          []
      end
    end)
  end

  defp type_loads(
         selections,
         context,
         type,
         constraints,
         load_opts,
         resource,
         field_name,
         resolution,
         path,
         selection,
         parent_type_name,
         original_type \\ nil,
         already_expanded? \\ false
       )

  defp type_loads(
         selections,
         context,
         {:array, type},
         constraints,
         load_opts,
         resource,
         field_name,
         resolution,
         path,
         selection,
         parent_type_name,
         original_type,
         already_expanded?
       ) do
    type_loads(
      selections,
      context,
      type,
      constraints[:items] || [],
      load_opts,
      resource,
      field_name,
      resolution,
      path,
      selection,
      parent_type_name,
      original_type,
      already_expanded?
    )
  end

  defp type_loads(
         selections,
         context,
         type,
         constraints,
         load_opts,
         resource,
         field_name,
         resolution,
         path,
         selection,
         parent_type_name,
         original_type,
         already_expanded?
       ) do
    cond do
      Ash.Type.NewType.new_type?(type) ->
        subtype_constraints = Ash.Type.NewType.constraints(type, constraints)
        subtype_of = Ash.Type.NewType.subtype_of(type)

        type_loads(
          selections,
          context,
          subtype_of,
          subtype_constraints,
          load_opts,
          resource,
          field_name,
          resolution,
          path,
          selection,
          parent_type_name,
          {type, constraints},
          already_expanded?
        )

      AshGraphql.Resource.embedded?(type) || Ash.Resource.Info.resource?(type) ||
          (type in [Ash.Type.Struct, :struct] && constraints[:instance_of] &&
             (AshGraphql.Resource.embedded?(constraints[:instance_of]) ||
                Ash.Resource.Info.resource?(constraints[:instance_of]))) ->
        type =
          if type in [:struct, Ash.Type.Struct] do
            constraints[:instance_of]
          else
            type
          end

        fields =
          if already_expanded? do
            selections
          else
            value_type =
              Absinthe.Schema.lookup_type(resolution.schema, selection.schema_node.type)

            {fields, _} =
              Absinthe.Resolution.Projector.project(
                selections,
                value_type,
                path,
                %{},
                resolution
              )

            fields
          end

        resource_loads(fields, type, resolution, load_opts, path, context)

      type == Ash.Type.Union ->
        {global_selections, fragments} =
          Enum.split_with(selections, fn
            %Absinthe.Blueprint.Document.Field{} ->
              true

            _ ->
              false
          end)

        loads =
          case global_selections do
            [] ->
              []

            global_selections ->
              first_type_config =
                constraints[:types]
                |> Enum.at(0)
                |> elem(1)

              first_type = first_type_config[:type]
              first_constraints = first_type_config[:constraints]

              type_loads(
                global_selections,
                context,
                first_type,
                first_constraints,
                load_opts,
                resource,
                field_name,
                resolution,
                path,
                selection,
                parent_type_name,
                original_type
              )
          end

        {graphql_unnested_unions, configured_type_name} =
          case original_type do
            {type, constraints} ->
              configured_type_name =
                cond do
                  function_exported?(type, :graphql_type, 0) ->
                    type.graphql_type()

                  function_exported?(type, :graphql_type, 1) ->
                    type.graphql_type(constraints)

                  true ->
                    nil
                end

              unnested_unions =
                if function_exported?(type, :graphql_unnested_unions, 1) do
                  type.graphql_unnested_unions(constraints)
                else
                  []
                end

              {unnested_unions, configured_type_name}

            _ ->
              {[], nil}
          end

        constraints[:types]
        |> Enum.filter(fn {_, config} ->
          Ash.Type.can_load?(config[:type], config[:constraints])
        end)
        |> Enum.reduce(loads, fn {type_name, config}, acc ->
          {gql_type_name, nested?} =
            if type_name in graphql_unnested_unions do
              {AshGraphql.Resource.field_type(
                 config[:type],
                 %Ash.Resource.Attribute{
                   name:
                     configured_type_name ||
                       AshGraphql.Resource.atom_enum_type(resource, field_name),
                   type: config[:type],
                   constraints: config[:constraints]
                 },
                 resource
               ), false}
            else
              {AshGraphql.Resource.nested_union_type_name(
                 %{name: configured_type_name || "#{parent_type_name}_#{field_name}"},
                 type_name,
                 true
               ), true}
            end

          gql_type = Absinthe.Schema.lookup_type(resolution.schema, gql_type_name)

          if !gql_type do
            raise Ash.Error.Framework.AssumptionFailed,
              message: "Could not find a corresponding graphql type for #{inspect(gql_type_name)}"
          end

          if nested? do
            {fields, _} =
              Absinthe.Resolution.Projector.project(
                fragments,
                gql_type,
                path,
                %{},
                resolution
              )

            if selection = Enum.find(fields, &(&1.schema_node.identifier == :value)) do
              Keyword.put(
                acc,
                type_name,
                type_loads(
                  selection.selections,
                  context,
                  config[:type],
                  config[:constraints],
                  load_opts,
                  resource,
                  gql_type_name,
                  resolution,
                  [selection | path],
                  selection,
                  gql_type_name,
                  original_type
                )
              )
            else
              acc
            end
          else
            {fields, _} =
              Absinthe.Resolution.Projector.project(
                fragments,
                gql_type,
                path,
                %{},
                resolution
              )

            Keyword.put(
              acc,
              type_name,
              type_loads(
                fields,
                context,
                config[:type],
                config[:constraints],
                load_opts,
                resource,
                gql_type_name,
                resolution,
                path,
                selection,
                gql_type_name,
                original_type,
                true
              )
            )
          end
        end)

      true ->
        []
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp mutation_result_type(mutation_name) do
    String.to_atom("#{mutation_name}_result")
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp page_type(resource, pagination, relay?) do
    type = AshGraphql.Resource.Info.type(resource)

    cond do
      relay? ->
        String.to_atom("#{type}_connection")

      pagination.keyset? ->
        String.to_atom("keyset_page_of_#{type}")

      pagination.offset? ->
        String.to_atom("page_of_#{type}")
    end
  end

  @doc false
  def select_fields(query_or_changeset, resource, resolution, type_override, nested \\ []) do
    type = type_override || AshGraphql.Resource.Info.type(resource)

    subfields =
      resolution
      |> fields(nested, type)
      |> names_only()
      |> Enum.map(&field_or_relationship(resource, &1))
      |> Enum.filter(& &1)
      |> Enum.map(& &1.name)

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

  defp fields(%Absinthe.Resolution{} = resolution, [], type) do
    resolution
    |> Absinthe.Resolution.project(type)
  end

  defp fields(%Absinthe.Resolution{} = resolution, names, _type) do
    # Here we don't pass the type to project because the Enum.reduce below already
    # takes care of projecting the nested fields using the correct type

    project =
      resolution
      |> Absinthe.Resolution.project()

    cache = resolution.fields_cache

    Enum.reduce(names, {project, cache}, fn name, {fields, cache} ->
      case fields |> Enum.find(&(&1.name == name)) do
        nil ->
          {fields, cache}

        selection ->
          type = Absinthe.Schema.lookup_type(resolution.schema, selection.schema_node.type)

          selection
          |> Map.get(:selections)
          |> Absinthe.Resolution.Projector.project(
            type,
            [selection | resolution.path],
            cache,
            resolution
          )
      end
    end)
    |> elem(0)
  end

  defp names_only(fields) do
    Enum.map(fields, & &1.schema_node.identifier)
  end

  @doc false
  def set_query_arguments(query, action, arg_values) do
    action =
      if is_atom(action) do
        Ash.Resource.Info.action(query.resource, action)
      else
        action
      end

    action.arguments
    |> Enum.filter(& &1.public?)
    |> Enum.reduce(query, fn argument, query ->
      case Map.fetch(arg_values, argument.name) do
        {:ok, value} ->
          Ash.Query.set_argument(query, argument.name, value)

        _ ->
          query
      end
    end)
  end

  defp add_root_errors(resolution, domain, {:error, error_or_errors}) do
    do_root_errors(domain, resolution, error_or_errors)
  end

  defp add_root_errors(resolution, domain, [_, {:error, error_or_errors}]) do
    do_root_errors(domain, resolution, error_or_errors)
  end

  defp add_root_errors(resolution, domain, [_, {:ok, %{errors: errors}}])
       when errors not in [nil, []] do
    do_root_errors(domain, resolution, errors, false)
  end

  defp add_root_errors(resolution, domain, {:ok, %{errors: errors}})
       when errors not in [nil, []] do
    do_root_errors(domain, resolution, errors, false)
  end

  defp add_root_errors(resolution, _domain, _other_thing) do
    resolution
  end

  defp do_root_errors(domain, resolution, error_or_errors, to_errors? \\ true) do
    if AshGraphql.Domain.Info.root_level_errors?(domain) do
      Map.update!(resolution, :errors, fn current_errors ->
        if to_errors? do
          Enum.concat(
            current_errors || [],
            List.wrap(to_errors(error_or_errors, resolution.context, domain))
          )
        else
          Enum.concat(current_errors || [], List.wrap(error_or_errors))
        end
      end)
    else
      resolution
    end
  end

  defp add_read_metadata({:error, error}, _, _) do
    {:error, error}
  end

  defp add_read_metadata({:ok, result}, query, action) do
    {:ok, add_read_metadata(result, query, action)}
  end

  defp add_read_metadata(nil, _, _), do: nil

  defp add_read_metadata(result, query, action) when is_list(result) do
    show_metadata = query.show_metadata || Enum.map(Map.get(action, :metadata, []), & &1.name)

    Enum.map(result, fn record ->
      do_add_read_metadata(record, show_metadata)
    end)
  end

  defp add_read_metadata(result, query, action) do
    show_metadata = query.show_metadata || Enum.map(Map.get(action, :metadata, []), & &1.name)

    do_add_read_metadata(result, show_metadata)
  end

  defp do_add_read_metadata(record, show_metadata) do
    Enum.reduce(show_metadata, record, fn key, record ->
      Map.put(record, key, Map.get(record.__metadata__ || %{}, key))
    end)
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

  defp destroy_result(result, initial, resource, changeset, domain, resolution) do
    case result do
      :ok ->
        {{:ok, %{result: clear_fields(initial, resource, resolution), errors: []}},
         [changeset, :ok]}

      {:error, %{changeset: changeset} = error} ->
        {{:ok, %{result: nil, errors: to_errors(changeset.errors, resolution.context, domain)}},
         {:error, error}}
    end
  end

  @doc false
  def unwrap_errors([]), do: []

  def unwrap_errors(errors) do
    errors
    |> List.wrap()
    |> Enum.flat_map(fn
      %class{errors: errors} when class in [Ash.Error.Invalid, Ash.Error.Forbidden] ->
        unwrap_errors(List.wrap(errors))

      errors ->
        List.wrap(errors)
    end)
  end

  defp to_errors(errors, context, domain) do
    AshGraphql.Errors.to_errors(errors, context, domain)
  end

  def resolve_calculation(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_calculation(
        %Absinthe.Resolution{
          source: parent,
          context: context
        } = resolution,
        {domain, resource, calculation}
      ) do
    domain = domain || context[:domain]

    result =
      if resolution.definition.alias do
        Map.get(parent.calculations, {:__ash_graphql_calculation__, resolution.definition.alias})
      else
        Map.get(parent, calculation.name)
      end

    case result do
      %struct{} when struct == Ash.ForbiddenField ->
        Absinthe.Resolution.put_result(
          resolution,
          to_resolution(
            {:error,
             Ash.Error.Forbidden.ForbiddenField.exception(
               resource: resource,
               field: resolution.definition.name
             )},
            context,
            domain
          )
        )

      result ->
        {type, constraints} =
          unwrap_type_and_constraints(calculation.type, calculation.constraints)

        result =
          if Ash.Type.NewType.new_type?(type) &&
               Ash.Type.NewType.subtype_of(type) == Ash.Type.Union &&
               function_exported?(type, :graphql_unnested_unions, 1) do
            unnested_types = type.graphql_unnested_unions(calculation.constraints)

            calculation = %{calculation | type: type, constraints: constraints}

            resolve_union_result(
              result,
              {calculation.name, calculation.type, calculation, resource, unnested_types, domain}
            )
          else
            result
          end

        Absinthe.Resolution.put_result(resolution, to_resolution({:ok, result}, context, domain))
    end
  end

  defp unwrap_type_and_constraints({:array, type}, constraints),
    do: unwrap_type_and_constraints(type, constraints[:items] || [])

  defp unwrap_type_and_constraints(other, constraints), do: {other, constraints}

  def resolve_assoc(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_assoc(
        %{source: parent} = resolution,
        {_domain, relationship}
      ) do
    value =
      if resolution.definition.alias do
        Map.get(parent.calculations, {:__ash_graphql_relationship__, resolution.definition.alias})
      else
        Map.get(parent, relationship.name)
      end

    Absinthe.Resolution.put_result(resolution, {:ok, value})
  end

  def resolve_id(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_id(
        %{source: parent} = resolution,
        {_resource, _field, relay_ids?}
      ) do
    Absinthe.Resolution.put_result(
      resolution,
      {:ok, AshGraphql.Resource.encode_id(parent, relay_ids?)}
    )
  end

  def resolve_union(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_union(
        %{source: parent, context: context} = resolution,
        {name, _field_type, _field, resource, _unnested_types, domain} = data
      ) do
    domain = domain || context[:domain]

    value =
      if resolution.definition.alias do
        Map.get(parent.calculations, {:__ash_graphql_attribute__, resolution.definition.alias})
      else
        Map.get(parent, name)
      end

    case value do
      %struct{} when struct == Ash.ForbiddenField ->
        Absinthe.Resolution.put_result(
          resolution,
          to_resolution(
            {:error,
             Ash.Error.Forbidden.ForbiddenField.exception(
               resource: resource,
               field: resolution.definition.name
             )},
            context,
            domain
          )
        )

      value ->
        result = resolve_union_result(value, data)

        Absinthe.Resolution.put_result(resolution, {:ok, result})
    end
  end

  def resolve_attribute(
        %{source: %resource{} = parent, context: context} = resolution,
        {name, type, constraints, domain}
      ) do
    domain = domain || context[:domain]

    value =
      if resolution.definition.alias && Ash.Type.can_load?(type, constraints) do
        Map.get(parent.calculations, {:__ash_graphql_attribute__, resolution.definition.alias})
      else
        Map.get(parent, name)
      end

    case value do
      %struct{} when struct == Ash.ForbiddenField ->
        Absinthe.Resolution.put_result(
          resolution,
          to_resolution(
            {:error,
             Ash.Error.Forbidden.ForbiddenField.exception(
               resource: resource,
               field: resolution.definition.name
             )},
            context,
            domain
          )
        )

      value ->
        Absinthe.Resolution.put_result(resolution, {:ok, value})
    end
  end

  def resolve_attribute(
        %{source: nil} = resolution,
        _
      ) do
    Absinthe.Resolution.put_result(resolution, {:ok, nil})
  end

  def resolve_attribute(
        %{source: parent} = resolution,
        {name, type, constraints, _domain}
      )
      when is_map(parent) do
    value =
      if resolution.definition.alias && Ash.Type.can_load?(type, constraints) do
        Map.get(parent.calculations, {:__ash_graphql_attribute__, resolution.definition.alias})
      else
        Map.get(parent, name)
      end

    Absinthe.Resolution.put_result(resolution, {:ok, value})
  end

  def resolve_attribute(
        %{source: source},
        _
      ) do
    raise "unknown source #{inspect(source)}"
  end

  defp resolve_union_result(value, data) when is_list(value) do
    Enum.map(value, &resolve_union_result(&1, data))
  end

  defp resolve_union_result(
         value,
         {_name, field_type, field, resource, unnested_types, _domain}
       ) do
    case value do
      %Ash.Union{type: type, value: value} = union ->
        constraints = Ash.Type.NewType.constraints(field_type, field.constraints)

        if type in unnested_types do
          if value do
            type =
              AshGraphql.Resource.field_type(
                constraints[:types][type][:type],
                %{field | constraints: constraints[:types][type][:constraints]},
                resource
              )

            Map.put(value, :__union_type__, type)
          end
        else
          union
        end

      other ->
        other
    end
  end

  def resolve_keyset(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_keyset(
        %{source: parent} = resolution,
        _field
      ) do
    Absinthe.Resolution.put_result(resolution, {:ok, Map.get(parent.__metadata__, :keyset)})
  end

  def resolve_composite_id(%Absinthe.Resolution{state: :resolved} = resolution, _),
    do: resolution

  def resolve_composite_id(
        %{source: parent} = resolution,
        {_resource, _fields, relay_ids?}
      ) do
    Absinthe.Resolution.put_result(
      resolution,
      {:ok, AshGraphql.Resource.encode_id(parent, relay_ids?)}
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

  def resolve_node(%{arguments: %{id: id}} = resolution, type_to_domain_and_resource_map) do
    case AshGraphql.Resource.decode_relay_id(id) do
      {:ok, %{type: type, id: primary_key}} ->
        {domain, resource} = Map.fetch!(type_to_domain_and_resource_map, type)
        # We can be sure this returns something since we check this at compile time
        query = AshGraphql.Resource.primary_key_get_query(resource)

        # We pass relay_ids? as false since we pass the already decoded primary key
        put_in(resolution.arguments.id, primary_key)
        |> resolve({domain, resource, query, false})

      {:error, _reason} = error ->
        Absinthe.Resolution.put_result(resolution, error)
    end
  end

  def resolve_node_type(%resource{}, _) do
    AshGraphql.Resource.Info.type(resource)
  end

  defp apply_load_arguments(arguments, query, will_paginate? \\ false) do
    Enum.reduce(arguments, query, fn
      {:limit, limit}, query when not will_paginate? ->
        Ash.Query.limit(query, limit)

      {:offset, offset}, query when not will_paginate? ->
        Ash.Query.offset(query, offset)

      {:filter, value}, query ->
        Ash.Query.do_filter(query, massage_filter(query.resource, value))

      {:sort, value}, query ->
        keyword_sort =
          Enum.map(value, fn %{order: order, field: field} = input ->
            case Ash.Resource.Info.calculation(query.resource, field) do
              %{arguments: [_ | _]} ->
                input_name = String.to_existing_atom("#{field}_input")

                {field, {input[input_name] || %{}, order}}

              _ ->
                {field, order}
            end
          end)

        Ash.Query.sort(query, keyword_sort)

      _, query ->
        query
    end)
  end

  defp to_resolution({:ok, value}, _context, _domain), do: {:ok, value}

  defp to_resolution({:error, error}, context, domain) do
    {:error,
     error
     |> unwrap_errors()
     |> Enum.map(fn error ->
       if AshGraphql.Error.impl_for(error) do
         error = AshGraphql.Error.to_error(error)

         case AshGraphql.Domain.Info.error_handler(domain) do
           nil ->
             error

           {m, f, a} ->
             apply(m, f, [error, context | a])
         end
       else
         uuid = Ash.UUID.generate()

         stacktrace =
           case error do
             %{stacktrace: %{stacktrace: v}} ->
               v

             _ ->
               nil
           end

         Logger.warning(
           "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
         )

         if AshGraphql.Domain.Info.show_raised_errors?(domain) do
           %{
             message: """
             Raised error: #{uuid}

             #{Exception.format(:error, error, stacktrace)}"
             """
           }
         else
           %{
             message: "Something went wrong. Unique error id: `#{uuid}`"
           }
         end
       end
     end)}
  end
end
