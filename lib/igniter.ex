defmodule AshGraphql.Igniter do
  @moduledoc "Codemods and utilities for working with AshGraphql & Igniter"

  @doc "Returns the AshGraphql schema containing the domain in question, or a list of all AshGraphql schemas"
  def find_schema(igniter, domain) do
    {igniter, modules} = ash_graphql_schemas(igniter)

    modules
    |> Enum.find(fn module ->
      with {:ok, {_igniter, _source, zipper}} <- Igniter.Code.Module.find_module(igniter, module),
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
    schema_name = schema_name || Igniter.Code.Module.module_name("GraphqlSchema")

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
                 Igniter.Code.Module.find_module(igniter, mod),
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
        """
        @desc "Remove me once you have a query of your own!"
        field :remove_me, :string do
          resolve fn _, _, _ ->
            {:ok, "Remove me!"}
          end
        end
        """
      end

    igniter
    |> Igniter.Code.Module.find_and_update_or_create_module(
      schema_name,
      """
      use Absinthe.Schema
      use AshGraphql, domains: #{inspect(domains)}

      query do
        # Custom absinthe queries can be placed here
        #{placeholder_query}
      end

      mutation do
        # Custom absinthe mutations can be placed here
      end
      """,
      fn zipper ->
        # Should never get here
        {:ok, zipper}
      end
    )
  end

  @doc "Sets up the phoenix module for AshGraphql"
  def setup_phoenix(igniter, schema_name \\ nil) do
    schema_name = schema_name || Igniter.Code.Module.module_name("GraphqlSchema")

    case Igniter.Libs.Phoenix.select_router(igniter) do
      {igniter, nil} ->
        igniter
        |> Igniter.add_warning("""
        No Phoenix router found, skipping phoenix installation.

        See the getting started guide for instructions on installing AshGraphql with `plug`.
        If you have yet to set up phoenix, you'll have to do that manually and then rerun this installer.
        """)

      {igniter, router} ->
        igniter
        |> Igniter.Libs.Phoenix.add_pipeline(:graphql, "plug AshGraphql.Plug", router: router)
        |> Igniter.Libs.Phoenix.add_scope(
          "/gql",
          """
            pipe_through [:graphql]

            forward "/playground",
                    Absinthe.Plug.GraphiQL,
                    schema: Module.concat(["#{inspect(schema_name)}"]),
                    interface: :playground

            forward "/",
              Absinthe.Plug,
              schema: Module.concat(["#{inspect(schema_name)}"])
          """,
          router: router
        )
    end
  end

  @doc "Returns all modules that `use AshGraphql`"
  def ash_graphql_schemas(igniter) do
    Igniter.Code.Module.find_all_matching_modules(igniter, fn _name, zipper ->
      match?({:ok, _}, Igniter.Code.Module.move_to_use(zipper, AshGraphql))
    end)
  end
end
