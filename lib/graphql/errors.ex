defmodule AshGraphql.Errors do
  @moduledoc """
  Utilities for working with errors in custom resolvers.
  """
  require Logger

  @doc """
  Transform an error or list of errors into the response for graphql.
  """
  def to_errors(errors, context, domain, resource) do
    errors
    |> AshGraphql.Graphql.Resolver.unwrap_errors()
    |> Enum.map(fn error ->
      if AshGraphql.Error.impl_for(error) do
        error = AshGraphql.Error.to_error(error)

        resource_handled_error =
          case AshGraphql.Resource.Info.error_handler(resource) do
            nil ->
              error

            {m, f, a} ->
              apply(m, f, [error, context | a])
          end

        case AshGraphql.Domain.Info.error_handler(domain) do
          nil ->
            resource_handled_error

          {m, f, a} ->
            apply(m, f, [resource_handled_error, context | a])
        end
      else
        uuid = Ash.UUID.generate()

        if is_exception(error) do
          case error do
            %{stacktrace: %{stacktrace: stacktrace}} ->
              Logger.warning(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
              )

            error ->
              Logger.warning(
                "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{Exception.format(:error, error)}"
              )
          end
        else
          Logger.warning(
            "`#{uuid}`: AshGraphql.Error not implemented for error:\n\n#{inspect(error)}"
          )
        end

        %{
          message: "something went wrong. Unique error id: `#{uuid}`"
        }
      end
    end)
  end
end
