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
      AshGraphql.Igniter.ash_graphql_schemas(igniter)

    if Enum.empty?(candidate_ash_graphql_schemas) do
      igniter
      |> AshGraphql.Igniter.setup_absinthe_schema(schema_name)
      |> AshGraphql.Igniter.setup_phoenix(schema_name)
    else
      igniter
      |> Igniter.add_warning("AshGraphql schema already exists, skipping installation.")
    end
  end
end
