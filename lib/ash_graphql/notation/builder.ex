defmodule AshGraphql.Notation.Builder do
  @moduledoc false

  alias Absinthe.Schema.Notation

  @doc false
  def container_identifier(domain, kind) do
    base =
      domain
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
      |> Enum.join("_")

    String.to_atom("#{base}_#{kind}")
  end

  @doc false
  def container_name(domain, kind) do
    suffix =
      case kind do
        :query -> "Queries"
        :mutation -> "Mutations"
        :subscription -> "Subscriptions"
      end

    domain
    |> Module.split()
    |> Enum.join("")
    |> Kernel.<>(suffix)
  end

  @doc false
  def add_container(module, schema, env, domain, kind, fields, acc) do
    if Enum.empty?(fields) do
      acc
    else
      identifier = container_identifier(domain, kind)
      name = container_name(domain, kind)

      definition = %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
        identifier: identifier,
        module: schema,
        name: name,
        fields: fields,
        __reference__: Notation.build_reference(env)
      }

      put_definition(module, definition)

      [identifier | acc]
    end
  end

  @doc false
  def put_definition(module, definition) do
    identifiers = Module.get_attribute(module, :ash_graphql_type_identifiers) || []

    unless definition.identifier in identifiers do
      Notation.put_attr(module, definition)

      Module.put_attribute(module, :ash_graphql_type_identifiers, [
        definition.identifier | identifiers
      ])
    end
  end

  @doc false
  def import_macro_ast(containers) do
    containers
    |> Enum.map(fn identifier ->
      quote do
        import_fields(unquote(identifier))
      end
    end)
    |> blockify()
  end

  defp blockify([]), do: quote(do: nil)
  defp blockify([single]), do: single
  defp blockify(list), do: {:__block__, [], list}
end
