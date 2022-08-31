defmodule AshGraphql.DocIndex do
  @moduledoc false

  use Spark.DocIndex,
    otp_app: :ash_graphql,
    guides_from: [
      "documentation/**/*.md"
    ]

  @impl true
  def for_library, do: "ash_graphql"

  @impl true
  def extensions do
    [
      %{
        module: AshGraphql.Resource,
        name: "AshGraphql Resource",
        target: "Ash.Resource",
        type: "GraphQL Resource"
      },
      %{
        module: AshGraphql.Api,
        name: "AshGraphql Api",
        target: "Ash.Api",
        type: "GraphQL Api"
      }
    ]
  end

  @impl true
  def code_modules do
    [
      {"Introspection",
       [
         AshGraphql.Resource.Info,
         AshGraphql.Api.Info
       ]}
    ]
  end
end
