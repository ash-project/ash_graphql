defmodule AshGraphql.Resource.Info do
  @moduledoc "Introspection helpers for AshGraphql.Resource"

  alias Spark.Dsl.Extension

  @doc "The queries exposed for the resource"
  def queries(resource) do
    Extension.get_entities(resource, [:graphql, :queries])
  end

  @doc "The mutations exposed for the resource"
  def mutations(resource) do
    Extension.get_entities(resource, [:graphql, :mutations]) || []
  end

  @doc "The managed_relationship configurations"
  def managed_relationships(resource) do
    Extension.get_entities(resource, [:graphql, :managed_relationships]) || []
  end

  @doc "The graphql type of the resource"
  def type(resource) do
    Extension.get_opt(resource, [:graphql], :type, nil)
  end

  @doc "The delimiter for a resource with a composite primary key"
  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:graphql], :primary_key_delimiter, nil)
  end

  @doc "Wether or not an object should be generated, or if one with the type name for this resource should be used."
  def generate_object?(resource) do
    Extension.get_opt(resource, [:graphql], :generate_object?, nil)
  end
end
