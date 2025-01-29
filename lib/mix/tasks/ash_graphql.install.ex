if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshGraphql.Install do
    @moduledoc "Installs AshGraphql. Should be run with `mix igniter.install ash_graphql`"
    @shortdoc @moduledoc
    require Igniter.Code.Common
    use Igniter.Mix.Task

    def igniter(igniter, _argv) do
      igniter =
        igniter
        |> Igniter.Project.Formatter.import_dep(:absinthe)
        |> Igniter.Project.Formatter.import_dep(:ash_graphql)
        |> Igniter.Project.Formatter.add_formatter_plugin(Absinthe.Formatter)
        |> Spark.Igniter.prepend_to_section_order(:"Ash.Resource", [:graphql])
        |> Spark.Igniter.prepend_to_section_order(:"Ash.Domain", [:graphql])

      schema_name = Igniter.Libs.Phoenix.web_module_name(igniter, "GraphqlSchema")

      {igniter, candidate_ash_graphql_schemas} =
        AshGraphql.Igniter.ash_graphql_schemas(igniter)

      if Enum.empty?(candidate_ash_graphql_schemas) do
        igniter
        |> AshGraphql.Igniter.setup_absinthe_schema(schema_name)
        |> AshGraphql.Igniter.setup_socket(schema_name, nil)
        |> AshGraphql.Igniter.setup_phoenix(schema_name, nil)
        |> AshGraphql.Igniter.setup_application()
      else
        igniter
        |> Igniter.add_warning("AshGraphql schema already exists, skipping installation.")
      end
    end
  end
else
  defmodule Mix.Tasks.AshGraphql.Install do
    @moduledoc "Installs AshGraphql. Should be run with `mix igniter.install ash_graphql`"
    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_graphql.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
