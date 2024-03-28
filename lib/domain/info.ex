defmodule AshGraphql.Domain.Info do
  @moduledoc "Introspection helpers for AshGraphql.Domain"

  alias Spark.Dsl.Extension

  @doc "Wether or not to run authorization on this domain"
  def authorize?(domain) do
    Extension.get_opt(domain, [:graphql], :authorize?, true)
  end

  @doc "The tracer to use for the given schema"
  def tracer(domain) do
    domain
    |> Extension.get_opt([:graphql], :tracer, nil, true)
    |> List.wrap()
    |> Enum.concat(List.wrap(Application.get_env(:ash, :tracer)))
  end

  @doc "Wether or not to surface errors to the root of the response"
  def root_level_errors?(domain) do
    Extension.get_opt(domain, [:graphql], :root_level_errors?, false, true)
  end

  @doc "An error handler for errors produced by domain"
  def error_handler(domain) do
    Extension.get_opt(
      domain,
      [:graphql],
      :error_handler,
      {AshGraphql.DefaultErrorHandler, :handle_error, []},
      true
    )
  end

  @doc "Wether or not to render raised errors in the graphql response"
  def show_raised_errors?(domain) do
    Extension.get_opt(domain, [:graphql], :show_raised_errors?, false, true)
  end
end
