if Code.ensure_loaded?(Igniter) do
  defmodule AshGraphql.Igniter do
    @moduledoc "Codemods and utilities for working with AshGraphql & Igniter"

    @doc "Returns the AshGraphql schema containing the domain in question, or a list of all AshGraphql schemas"
    def find_schema(igniter, domain) do
      {igniter, modules} = ash_graphql_schemas(igniter)

      modules
      |> Enum.find(fn module ->
        with {:ok, {_igniter, _source, zipper}} <-
               Igniter.Project.Module.find_module(igniter, module),
             {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, AshGraphql),
             {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
             {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :domains),
             {:ok, _zipper} <-
               Igniter.Code.List.move_to_list_item(
                 zipper,
                 &Igniter.Code.Common.nodes_equal?(&1, domain)
               ) do
          true
        else
          _ ->
            false
        end
      end)
      |> case do
        nil ->
          {:error, igniter, modules}

        module ->
          {:ok, igniter, module}
      end
    end

    @doc "Sets up an absinthe schema for AshGraphql"
    def setup_absinthe_schema(igniter, schema_name \\ nil) do
      schema_name = schema_name || Igniter.Project.Module.module_name(igniter, "GraphqlSchema")

      {igniter, domains} = Ash.Domain.Igniter.list_domains(igniter)

      {igniter, domains} =
        Enum.reduce(domains, {igniter, []}, fn domain, {igniter, list} ->
          case Spark.Igniter.has_extension(
                 igniter,
                 domain,
                 Ash.Domain,
                 :extensions,
                 AshGraphql.Domain
               ) do
            {igniter, true} -> {igniter, [domain | list]}
            {igniter, false} -> {igniter, list}
          end
        end)

      {igniter, resources} = Ash.Resource.Igniter.list_resources(igniter)

      {igniter, any_queries?} =
        Enum.reduce_while(
          Enum.map(resources, &{&1, [2, 3]}) ++ Enum.map(domains, &{&1, [3, 4]}),
          {igniter, false},
          fn {mod, arities}, {igniter, false} ->
            with {:ok, {igniter, _source, zipper}} <-
                   Igniter.Project.Module.find_module(igniter, mod),
                 {:ok, zipper} <-
                   Igniter.Code.Function.move_to_function_call_in_current_scope(
                     zipper,
                     :graphql,
                     1
                   ),
                 {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
                 {:ok, zipper} <-
                   Igniter.Code.Function.move_to_function_call_in_current_scope(
                     zipper,
                     :queries,
                     1
                   ),
                 {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
              has_query? =
                Enum.any?([:get, :read_one, :list, :action], fn query_name ->
                  match?(
                    {:ok, _},
                    Igniter.Code.Function.move_to_function_call_in_current_scope(
                      zipper,
                      query_name,
                      arities
                    )
                  )
                end)

              if has_query? do
                {:halt, {igniter, true}}
              else
                {:cont, {igniter, false}}
              end
            else
              _ ->
                {:cont, {igniter, false}}
            end
          end
        )

      placeholder_query =
        unless any_queries? do
          ~S'''
          @desc """
          Hello! This is a sample query to verify that AshGraphql has been set up correctly.
          Remove me once you have a query of your own!
          """
          field :say_hello, :string do
            resolve fn _, _, _ ->
              {:ok, "Hello from AshGraphql!"}
            end
          end
          '''
        end

      igniter
      |> Igniter.Project.Module.find_and_update_or_create_module(
        schema_name,
        """
        use Absinthe.Schema

        use AshGraphql,
          domains: #{inspect(domains)}

        import_types Absinthe.Plug.Types

        query do
          # Custom Absinthe queries can be placed here
          #{placeholder_query}
        end

        mutation do
          # Custom Absinthe mutations can be placed here
        end

        subscription do
          # Custom Absinthe subscriptions can be placed here
        end
        """,
        fn zipper ->
          # Should never get here
          {:ok, zipper}
        end
      )
    end

    @doc "Sets up the phoenix module for AshGraphql"
    def setup_phoenix(igniter, schema_name \\ nil, socket_name \\ nil, opts \\ []) do
      schema_name = schema_name || Igniter.Project.Module.module_name(igniter, "GraphqlSchema")
      socket_name = socket_name || Igniter.Project.Module.module_name(igniter, "GraphqlSocket")

      case Igniter.Libs.Phoenix.select_router(igniter) do
        {igniter, nil} ->
          igniter
          |> Igniter.add_warning("""
          No Phoenix router found, skipping Phoenix installation.

          See the Getting Started guide for instructions on installing AshGraphql with `plug`.
          If you have yet to set up Phoenix, you'll have to do that manually and then rerun this installer.
          """)

        {igniter, router} ->
          igniter
          |> Igniter.Project.Deps.add_dep({:absinthe_phoenix, "~> 2.0"})
          |> then(fn igniter ->
            if igniter.assigns[:test_mode?] do
              igniter
            else
              Igniter.apply_and_fetch_dependencies(igniter,
                error_on_abort?: true,
                yes: opts[:yes],
                yes_to_deps: true
              )
            end
          end)
          |> create_socket(schema_name, socket_name)
          |> update_router(router, socket_name, schema_name)
          |> update_application(router)
      end
    end

    defp update_router(igniter, router, socket_name, schema_name) do
      igniter
      |> update_endpoints(router, socket_name)
      |> Igniter.Libs.Phoenix.add_pipeline(:graphql, "plug AshGraphql.Plug", router: router)
      |> Igniter.Libs.Phoenix.add_scope(
        "/gql",
        """
          pipe_through [:graphql]

          forward "/playground",
                  Absinthe.Plug.GraphiQL,
                  schema: Module.concat(["#{inspect(schema_name)}"]),
                  socket: Module.concat(["#{inspect(socket_name)}"]),
                  interface: :playground

          forward "/",
            Absinthe.Plug,
            schema: Module.concat(["#{inspect(schema_name)}"])
        """,
        router: router
      )
    end

    defp update_application(igniter, router) do
      {igniter, endpoints} =
        Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)

      igniter =
        Enum.reduce(endpoints, igniter, fn endpoint, igniter ->
          igniter
          |> Igniter.Project.Application.add_new_child({Absinthe.Subscription, endpoint},
            after: endpoint
          )
        end)

      igniter
      |> Igniter.Project.Application.add_new_child(AshGraphql.Subscription.Batcher,
        after: Absinthe.Subscription
      )
    end

    defp create_socket(igniter, schema_name, socket_name) do
      igniter
      |> Igniter.Project.Module.find_and_update_or_create_module(
        socket_name,
        """
        use Phoenix.Socket

        use Absinthe.Phoenix.Socket,
          schema: #{inspect(schema_name)}

        @impl true
        def connect(_params, socket, _connect_info) do
          {:ok, socket}
        end

        @impl true
        def id(_socket), do: nil
        """,
        fn zipper ->
          # Should never get here
          {:ok, zipper}
        end
      )
    end

    @doc "Returns all modules that `use AshGraphql`"
    def ash_graphql_schemas(igniter) do
      Igniter.Project.Module.find_all_matching_modules(igniter, fn _name, zipper ->
        match?({:ok, _}, Igniter.Code.Module.move_to_use(zipper, AshGraphql))
      end)
    end

    defp update_endpoints(igniter, router, socket_name) do
      {igniter, endpoints_that_need_parser} =
        Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)

      igniter =
        Enum.reduce(endpoints_that_need_parser, igniter, fn endpoint, igniter ->
          igniter
          |> Igniter.Project.Module.find_and_update_module!(endpoint, fn zipper ->
            with {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, Phoenix.Endpoint) do
              {:ok, Igniter.Code.Common.add_code(zipper, "use Absinthe.Phoenix.Endpoint")}
            end
          end)
          |> Igniter.Project.Module.find_and_update_module!(endpoint, fn zipper ->
            case Igniter.Code.Function.move_to_function_call_in_current_scope(
                   zipper,
                   :plug,
                   2,
                   &Igniter.Code.Function.argument_equals?(&1, 0, Plug.Parsers)
                 ) do
              {:ok, zipper} ->
                with {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
                     {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :parsers),
                     {:ok, zipper} <-
                       Igniter.Code.List.append_new_to_list(zipper, Absinthe.Plug.Parser) do
                  {:ok, zipper}
                else
                  _ ->
                    {:warning,
                     "Could not add `Absinthe.Plug.Parser` to parsers in endpoint #{endpoint}. Please make this change manually."}
                end

              :error ->
                case parser_location(zipper) do
                  {:ok, zipper} ->
                    {:ok,
                     Igniter.Code.Common.add_code(zipper, """
                     plug Plug.Parsers,
                       parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
                       pass: ["*/*"],
                       json_decoder: Jason
                     """)}

                  _ ->
                    {:warning,
                     "Could not add `Absinthe.Plug.Parser` to parsers in endpoint #{endpoint}. Please make this change manually."}
                end
            end
          end)
        end)

      Enum.reduce(endpoints_that_need_parser, igniter, fn endpoint, igniter ->
        Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
          case Igniter.Code.Function.move_to_function_call_in_current_scope(
                 zipper,
                 :socket,
                 3,
                 &Igniter.Code.Function.argument_equals?(&1, 1, socket_name)
               ) do
            {:ok, zipper} ->
              # Already installed
              {:ok, zipper}

            :error ->
              case socket_location(zipper) do
                {:ok, zipper} ->
                  {:ok,
                   Igniter.Code.Common.add_code(zipper, """
                     socket "/ws/gql", #{inspect(socket_name)},
                       websocket: true,
                       longpoll: true
                   """)}

                _ ->
                  {:warning,
                   "Could not add #{socket_name} in endpoint #{endpoint}. Please make this change manually."}
              end
          end
        end)
      end)
    end

    defp socket_location(zipper) do
      with :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :socket,
               3,
               &Igniter.Code.Function.argument_equals?(&1, 1, Phoenix.LiveView.Socket)
             ) do
        Igniter.Code.Module.move_to_use(zipper, Phoenix.Endpoint)
      end
    end

    defp parser_location(zipper) do
      with :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :plug,
               [1, 2],
               &Igniter.Code.Function.argument_equals?(&1, 0, Plug.Telemetry)
             ),
           :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :plug,
               [1, 2]
             ) do
        Igniter.Code.Module.move_to_use(zipper, Phoenix.Endpoint)
      end
    end
  end
end
