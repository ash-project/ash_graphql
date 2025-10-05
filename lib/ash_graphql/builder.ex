defmodule AshGraphql.Builder do
  @moduledoc false

  require Ash.Domain.Info

  @doc false
  def compile_context(opts) do
    auto_import_types =
      if Keyword.get(opts, :auto_import_absinthe_types?, true) do
        quote do
          import_types(Absinthe.Type.Custom)
          import_types(AshGraphql.Types.JSON)
          import_types(AshGraphql.Types.JSONString)
        end
      end

    domains =
      opts[:domain]
      |> List.wrap()
      |> Kernel.++(List.wrap(opts[:domains]))
      |> Enum.uniq()
      |> Enum.map(fn
        {domain, _registry} ->
          IO.warn("""
          It is no longer required to list the registry along with a domain when using `AshGraphql`

             use AshGraphql, domains: [{My.App.Domain, My.App.Registry}]

          Can now be stated simply as

             use AshGraphql, domains: [My.App.Domain]
          """)

          domain

        domain ->
          domain
      end)
      |> Enum.map(fn domain -> {domain, Ash.Domain.Info.resources(domain), false} end)
      |> Enum.reduce({[], []}, fn {domain, resources, first?}, {acc, seen_resources} ->
        resources = Enum.reject(resources, &(&1 in seen_resources))

        {[{domain, resources, first?} | acc], seen_resources ++ resources}
      end)
      |> elem(0)
      |> Enum.reverse()

    domains =
      case domains do
        [] ->
          []

        list ->
          List.update_at(list, 0, fn {domain, resources, _} ->
            {domain, resources, true}
          end)
      end

    ash_resources = Enum.flat_map(domains, &elem(&1, 1))
    Enum.each(ash_resources, &Code.ensure_compiled!/1)

    %{
      action_middleware: opts[:action_middleware] || [],
      all_domains: Enum.map(domains, &elem(&1, 0)),
      ash_resources: ash_resources,
      auto_generate_sdl_file?: opts[:auto_generate_sdl_file?],
      auto_import_types: auto_import_types,
      define_relay_types?: Keyword.get(opts, :define_relay_types?, true),
      domains: domains,
      domains_with_resources:
        Enum.map(domains, fn {domain, resources, _} -> {domain, resources} end),
      generate_sdl_file: opts[:generate_sdl_file],
      relay_ids?: Keyword.get(opts, :relay_ids?, false)
    }
  end
end
