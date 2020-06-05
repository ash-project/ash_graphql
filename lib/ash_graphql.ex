defmodule AshGraphql do
  @moduledoc """
  Documentation for `AshGraphql`.
  """

  def fields(resource) do
    resource.graphql_fields()
  end

  def type(resource) do
    resource.graphql_type()
  end
end
