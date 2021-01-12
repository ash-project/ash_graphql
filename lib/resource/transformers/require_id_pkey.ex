defmodule AshGraphql.Resource.Transformers.RequireIdPkey do
  @moduledoc "Ensures that the resource has a primary key called `id`"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  def transform(resource, dsl) do
    if Ash.Type.embedded_type?(resource) do
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
          if AshGraphql.Resource.primary_key_delimiter(resource) do
            {:ok, dsl}
          else
            {:error,
             "AshGraphql requires a `primary_key_delimiter` to be set for composite primary keys."}
          end
      end
    end
  end
end
