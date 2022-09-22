defmodule AshGraphql.Resource.Helpers do
  @moduledoc "Imported helpers for the graphql DSL section"

  @doc """
  A list of a given type, idiomatic for those used to `absinthe` notation.
  """
  @spec list_of(v) :: {:array, v} when v: term()
  def list_of(value) do
    {:array, value}
  end

  @doc """
  A non nullable type, idiomatic for those used to `absinthe` notation.
  """
  @spec non_null(v) :: {:non_null, v} when v: term()
  def non_null(value) do
    {:non_null, value}
  end
end
