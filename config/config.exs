import Config

config :ash, :disable_async?, true
config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false

config :logger, level: :warning

config :ash, :pub_sub, debug?: true
config :logger, level: :debug

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshGraphql.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_graphql",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: [
      "README.md",
      "documentation/tutorials/getting-started-with-graphql.md"
    ],
    version_tag_prefix: "v"
end
