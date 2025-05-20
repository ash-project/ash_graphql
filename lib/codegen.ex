defmodule AshGraphql.Codegen do
  @moduledoc false

  # sobelow_skip ["Traversal.FileModule"]
  def generate_sdl_file(schema, opts) do
    target = schema.generate_sdl_file()

    case Mix.Tasks.Absinthe.Schema.Sdl.generate_schema(%Mix.Tasks.Absinthe.Schema.Sdl.Options{
           schema: schema,
           filename: target
         }) do
      {:ok, contents} ->
        if opts[:check?] do
          target_contents = File.read!(target)

          if String.trim(target_contents) != String.trim(contents) do
            raise "Generated SDL file for #{inspect(schema)} does not match existing file. Please run `mix ash.codegen` to  generate the new  file."
          end
        else
          File.write!(target, contents)
        end

      error ->
        raise """
        Failed to generate absinthe schema for: #{inspect(schema)}

        Error:

        #{inspect(error)}
        """
    end
  end

  def __after_compile__(env, _bytecode) do
    file = env.module.generate_sdl_file()

    if file && env.module.auto_generate_sdl_file?() do
      generate_sdl_file(env.module, [])
    end
  end

  def schemas do
    apps =
      if Code.ensure_loaded?(Mix.Project) do
        if apps_paths = Mix.Project.apps_paths() do
          apps_paths |> Map.keys() |> Enum.sort()
        else
          [Mix.Project.config()[:app]]
        end
      else
        []
      end

    apps()
    |> Stream.concat(apps)
    |> Stream.uniq()
    |> Task.async_stream(
      fn app ->
        app
        |> :application.get_key(:modules)
        |> case do
          :undefined ->
            []

          {_, mods} ->
            mods
            |> List.wrap()
            |> Enum.filter(&ash_graphql_schema?/1)
        end
      end,
      timeout: :infinity
    )
    |> Stream.map(&elem(&1, 1))
    |> Stream.flat_map(& &1)
    |> Stream.uniq()
    |> Enum.to_list()
  end

  defp ash_graphql_schema?(module) do
    Code.ensure_compiled!(module)
    function_exported?(module, :ash_graphql_schema?, 0) && module.ash_graphql_schema?()
  end

  Code.ensure_loaded!(Mix.Project)

  if function_exported?(Mix.Project, :deps_tree, 0) do
    # for our app, and all dependency apps, we want to find extensions
    # the benefit of not just getting all loaded applications is that this
    # is actually a surprisingly expensive thing to do for every single built
    # in application for elixir/erlang. Instead we get anything w/ a dependency on ash or spark
    # this could miss things, but its unlikely. And if it misses things, it actually should be
    # fixed in the dependency that is relying on a transitive dependency :)
    defp apps do
      Mix.Project.deps_tree()
      |> Stream.filter(fn {_, nested_deps} ->
        Enum.any?(nested_deps, &(&1 == :spark || &1 == :ash))
      end)
      |> Stream.map(&elem(&1, 0))
    end
  else
    defp apps do
      Logger.warning(
        "Mix.Project.deps_tree/0 not available, falling back to loaded_applications/0. Upgrade to Elixir 1.15+ to make this *much* faster."
      )

      :application.loaded_applications()
      |> Stream.map(&elem(&1, 0))
    end
  end
end
