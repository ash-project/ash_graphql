defmodule AshGraphql.Api.Info do
  @moduledoc "Introspection helpers for AshGraphql.Api"

  alias Spark.Dsl.Extension

  @doc "Wether or not to run authorization on this api"
  def authorize?(api) do
    Extension.get_opt(api, [:graphql], :authorize?, true)
  end

  @doc "Wether or not to surface errors to the root of the response"
  def root_level_errors?(api) do
    Extension.get_opt(api, [:graphql], :root_level_errors?, false, true)
  end

  @doc "Wether or not to render raised errors in the graphql response"
  def show_raised_errors?(api) do
    Extension.get_opt(api, [:graphql], :show_raised_errors?, false, true)
  end

  @doc "Wether or not to pass debug? down to internal execution"
  def debug?(api) do
    Extension.get_opt(api, [:graphql], :debug?, false)
  end

  @doc "Wether or not to show stacktraces? in the graphql response"
  def stacktraces?(api) do
    Extension.get_opt(api, [:graphql], :stacktraces?, false)
  end
end
