defmodule AshGraphql.TraceHelpers do
  @moduledoc false

  defmacro trace(api, resource, type, name, metadata, do: body) do
    quote do
      require Ash.Tracer
      api = unquote(api)
      resource = unquote(resource)
      type = unquote(type)
      name = unquote(name)
      metadata = unquote(metadata)

      Ash.Tracer.span type,
                      AshGraphql.TraceHelpers.span_name(api, resource, type, name),
                      AshGraphql.Api.Info.tracer(api) do
        Ash.Tracer.set_metadata(AshGraphql.Api.Info.tracer(api), type, metadata)

        Ash.Tracer.telemetry_span [:ash, Ash.Api.Info.short_name(api), type], metadata do
          unquote(body)
        end
      end
    end
  end

  def span_name(api, resource, type, name)
      when is_atom(api) and is_atom(resource) and is_atom(type) and
             (is_atom(name) or is_binary(name)) do
    Ash.Api.Info.span_name(api, resource, "#{type}.#{name}")
  end
end
