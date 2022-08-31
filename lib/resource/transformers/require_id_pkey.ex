defmodule AshGraphql.Resource.Transformers.RequireIdPkey do
  @moduledoc "Ensures that the resource has a primary key called `id`"
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    if Transformer.get_persisted(dsl, :embedded?) do
      {:ok, dsl}
    else
      primary_key =
        dsl
        |> Transformer.get_entities([:attributes])
        |> Enum.filter(& &1.primary_key?)

      case primary_key do
        [_single] ->
          {:ok, dsl}

        [_ | _] ->
          if Transformer.get_persisted(dsl, :primary_key) do
            {:ok, dsl}
          else
            {:error,
             "AshGraphql requires a `primary_key_delimiter` to be set for composite primary keys."}
          end
      end
    end
  end

  def after?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def after?(_), do: false
end
