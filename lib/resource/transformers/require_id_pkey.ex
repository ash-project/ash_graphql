defmodule AshGraphql.Resource.Transformers.RequireIdPkey do
  @moduledoc "Ensures that the resource has a primary key called `id`"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  def transform(_resource, dsl) do
    primary_key =
      dsl
      |> Transformer.get_entities([:attributes])
      |> Enum.filter(& &1.primary_key?)
      |> Enum.map(& &1.name)

    unless primary_key == [:id] do
      raise "AshGraphql currently requires the primary key to be a field called `id`"
    end

    {:ok, dsl}
  end
end
