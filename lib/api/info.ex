defmodule AshGraphql.Api.Info do
  @moduledoc "Introspection helpers for AshGraphql.Api"

  alias Spark.Dsl.Extension

  @doc "Wether or not to run authorization on this api"
  def authorize?(api) do
    Extension.get_opt(api, [:graphql], :authorize?, true)
  end

  @doc "The tracer to use for the given schema"
  def tracer(api) do
    api
    |> Extension.get_opt([:graphql], :tracer, nil, true)
    |> List.wrap()
    |> Enum.concat(List.wrap(Application.get_env(:ash, :tracer)))
  end

  @doc "Wether or not to surface errors to the root of the response"
  def root_level_errors?(api) do
    Extension.get_opt(api, [:graphql], :root_level_errors?, false, true)
  end

  @doc "An error handler for errors produced by api"
  def error_handler(api) do
    Extension.get_opt(
      api,
      [:graphql],
      :error_handler,
      {AshGraphql.DefaultErrorHandler, :handle_error, []},
      true
    )
  end

  @doc "Wether or not to render raised errors in the graphql response"
  def show_raised_errors?(api) do
    Extension.get_opt(api, [:graphql], :show_raised_errors?, false, true)
  end

  @doc "Wether or not to pass debug? down to internal execution"
  def debug?(api) do
    Extension.get_opt(api, [:graphql], :debug?, false)
  end
end
