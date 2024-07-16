defmodule Mix.Tasks.AshGraphql.Install do
  @moduledoc "Installs AshGraphql. Should be run with `mix igniter.install ash_postgres`"
  @shortdoc @moduledoc
  require Igniter.Code.Common
  use Igniter.Mix.Task

  def igniter(igniter, _argv) do
    igniter =
      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_graphql)
      |> Spark.Igniter.prepend_to_section_order(:"Ash.Resource", [:graphql])
      |> Spark.Igniter.prepend_to_section_order(:"Ash.Domain", [:graphql])

    schema_name = Igniter.Code.Module.module_name("GraphqlSchema")

    {igniter, candidate_ash_graphql_schemas} =
      Igniter.Code.Module.find_all_matching_modules(igniter, fn _name, zipper ->
        zipper
        |> Igniter.Code.Module.move_to_use(AshGraphql)
      end)

    if Enum.empty?(candidate_ash_graphql_schemas) do
      igniter
      |> setup_absinthe_schema(schema_name)
      |> setup_web(schema_name)
    else
      igniter
      |> Igniter.add_warning("AshGraphql schema already exists, skipping installation.")
    end
  end

  defp setup_web(igniter, schema_name) do
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

  defp setup_absinthe_schema(igniter, schema_name) do
    {igniter, domains} = Ash.Domain.Igniter.list_domains(igniter)
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
    |> Igniter.Code.Module.find_and_update_or_create_module(
      schema_name,
      """
      use Absinthe.Schema
      use AshGraphql, domains: #{inspect(domains)}

      query do
        # Custom Absinthe queries can be placed here
        #{placeholder_query}
      end

      mutation do
        # Custom Absinthe mutations can be placed here
      end
      """,
      fn zipper ->
        # Should never get here
        {:ok, zipper}
      end
    )
  end
end
