defmodule AshGraphql.TraceHelpers do
  @moduledoc false

  defmacro trace(domain, resource, type, name, metadata, do: body) do
    quote do
      require Ash.Tracer
      domain = unquote(domain)
      resource = unquote(resource)
      type = unquote(type)
      name = unquote(name)
      metadata = unquote(metadata)

      Ash.Tracer.span type,
                      AshGraphql.TraceHelpers.span_name(domain, resource, type, name),
                      AshGraphql.Domain.Info.tracer(domain) do
        Ash.Tracer.set_metadata(AshGraphql.Domain.Info.tracer(domain), type, metadata)

        Ash.Tracer.telemetry_span [:ash, Ash.Domain.Info.short_name(domain), type], metadata do
          unquote(body)
        end
      end
    end
  end

  def span_name(domain, resource, type, name)
      when is_atom(domain) and is_atom(resource) and is_atom(type) and
             (is_atom(name) or is_binary(name)) do
    Ash.Domain.Info.span_name(domain, resource, "#{type}.#{name}")
  end
end
