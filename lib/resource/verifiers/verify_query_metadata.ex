defmodule AshGraphql.Resource.Verifiers.VerifyQueryMetadata do
  # Ensures that queries for actions with metadata have a type set
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  def verify(dsl) do
    dsl
    |> AshGraphql.Resource.Info.queries()
    |> Enum.reject(&(&1.type == :action))
    |> Enum.each(fn query ->
      action = Ash.Resource.Info.action(dsl, query.action)
      show_metadata = query.show_metadata || Enum.map(Map.get(action, :metadata, []), & &1.name)

      metadata =
        action
        |> Map.get(:metadata, [])
        |> Enum.filter(&(&1.name in show_metadata))

      if !Enum.empty?(metadata) && is_nil(query.type_name) do
        resource = Transformer.get_persisted(dsl, :module)

        raise Spark.Error.DslError,
          module: resource,
          message: """
          Queries for actions with metadata must have a type configured on the query.

          The #{query.action} action on #{inspect(resource)} has the following metadata fields:

          #{Enum.map_join(action.metadata, "\n", &"* #{&1.name}")}

          To generate a new type and include the metadata in that type, provide a new type
          name, for example `type :user_with_token`.

          To ignore the generated metadata, use the same type as the default.
          """
      end
    end)

    :ok
  end
end
