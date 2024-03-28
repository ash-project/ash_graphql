defmodule AshGraphql.MixProject do
  use Mix.Project

  @description """
  An absinthe-backed graphql extension for Ash
  """

  @version "0.27.1"

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
      dialyzer: [plt_add_apps: [:ash]],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      docs: docs(),
      description: @description,
      source_url: "https://github.com/ash-project/ash_graphql",
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
      main: "getting-started-with-graphql",
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
        "documentation/tutorials/getting-started-with-graphql.md",
        "documentation/how_to/authorize-with-graphql.md",
        "documentation/how_to/handle-errors.md",
        "documentation/how_to/use-enums-with-graphql.md",
        "documentation/how_to/use-json-with-graphql.md",
        "documentation/how_to/use-subscriptions-with-graphql.md",
        "documentation/how_to/use-unions-with-graphql.md",
        "documentation/topics/monitoring.md",
        "documentation/topics/graphql-generation.md",
        "documentation/topics/modifying-the-resolution.md",
        "documentation/topics/relay.md",
        "documentation/dsls/DSL:-AshGraphql.Domain.md",
        "documentation/dsls/DSL:-AshGraphql.Resource.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls'
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
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/ash_graphql"
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
      {:ash, ash_version("~> 3.0-dev")},
      {:absinthe_plug, "~> 1.4"},
      {:absinthe, "~> 1.7"},
      {:jason, "~> 1.2"},
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:excoveralls, "~> 0.13", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:simple_sat, ">= 0.0.0", only: :test}
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
        "spark.replace_doc_links",
        "spark.cheat_sheets_in_search"
      ],
      "spark.formatter": "spark.formatter --extensions AshGraphql.Resource,AshGraphql.Domain",
      "spark.cheat_sheets_in_search":
        "spark.cheat_sheets_in_search --extensions AshGraphql.Resource,AshGraphql.Domain",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshGraphql.Resource,AshGraphql.Domain"
    ]
  end
end
