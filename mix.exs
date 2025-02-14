defmodule AshGraphql.MixProject do
  use Mix.Project

  @description """
  The extension for building GraphQL APIs with Ash
  """

  @version "1.6.0"

  @source_url "https://github.com/ash-project/ash_graphql"

  def project do
    [
      app: :ash_graphql,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      package: package(),
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_add_apps: [:ash, :mix]],
      docs: &docs/0,
      description: @description,
      source_url: @source_url,
      homepage_url: "https://github.com/ash-project/ash_graphql"
    ]
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:dev) ++ ["test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end,
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/getting-started-with-graphql.md",
        "documentation/topics/authorize-with-graphql.md",
        "documentation/topics/handle-errors.md",
        "documentation/topics/generic-actions.md",
        "documentation/topics/sdl-file.md",
        "documentation/topics/use-enums-with-graphql.md",
        "documentation/topics/use-json-with-graphql.md",
        "documentation/topics/use-subscriptions-with-graphql.md",
        "documentation/topics/use-unions-with-graphql.md",
        "documentation/topics/use-maps-with-graphql.md",
        "documentation/topics/monitoring.md",
        "documentation/topics/graphql-generation.md",
        "documentation/topics/modifying-the-resolution.md",
        "documentation/topics/relay.md",
        "documentation/topics/custom-queries-and-mutations.md",
        "documentation/topics/upgrade.md",
        {"documentation/dsls/DSL-AshGraphql.Domain.md",
         search_data: Spark.Docs.search_data_for(AshGraphql.Domain)},
        {"documentation/dsls/DSL-AshGraphql.Resource.md",
         search_data: Spark.Docs.search_data_for(AshGraphql.Resource)},
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls',
        "About AshGraphql": [
          "CHANGELOG.md"
        ]
      ],
      groups_for_modules: [
        AshGraphql: [
          AshGraphql
        ],
        Introspection: [
          AshGraphql.Resource.Info,
          AshGraphql.Domain.Info,
          AshGraphql.Resource,
          AshGraphql.Domain,
          AshGraphql.Resource.Action,
          AshGraphql.Resource.ManagedRelationship,
          AshGraphql.Resource.Mutation,
          AshGraphql.Resource.Query
        ],
        Errors: [
          AshGraphql.Error,
          AshGraphql.Errors
        ],
        Miscellaneous: [
          AshGraphql.Resource.Helpers
        ],
        Utilities: [
          AshGraphql.ContextHelpers,
          AshGraphql.DefaultErrorHandler,
          AshGraphql.Plug,
          AshGraphql.Subscription,
          AshGraphql.Type,
          AshGraphql.Types.JSON,
          AshGraphql.Types.JSONString
        ]
      ]
    ]
  end

  defp package do
    [
      name: :ash_graphql,
      licenses: ["MIT"],
      maintainers: "Zach Daniel",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        "GitHub" => @source_url,
        "Discord" => "https://discord.gg/HTHRaaVPUc",
        "Website" => "https://ash-hq.org",
        "Forum" => "https://elixirforum.com/c/ash-framework-forum/",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, ash_version("~> 3.0 and >= 3.2.3")},
      {:absinthe_plug, "~> 1.4"},
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0.0", optional: true},
      {:jason, "~> 1.2"},
      {:igniter, path: "../igniter", optional: true, override: true},
      {:spark, "~> 2.2 and >= 2.2.10"},
      {:owl, "~> 0.11"},
      # dev/test dependencies
      {:ex_doc, "~> 0.37-rc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:simple_sat, ">= 0.0.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.1", only: [:dev, :test]},
      {:phx_new, "~> 1.5", only: [:test]}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      "spark.formatter": "spark.formatter --extensions AshGraphql.Resource,AshGraphql.Domain",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshGraphql.Resource,AshGraphql.Domain"
    ]
  end
end
