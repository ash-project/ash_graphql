# Using the SDL File

By passing the `generate_sdl_file` to `use AshGraphql`, AshGraphql will generate
a schema file when you run `mix ash.codegen`. For example:

```elixir
use AshGraphql,
  domains: [Domain1, Domain2],
  generate_sdl_file: "priv/schema.graphql"
```

> ### Ensure your schema is up to date, gitignored, or not generated {: .info}
>
> We suggest first adding `mix ash.codegen --check` to your CI/CD pipeline to
> ensure the schema is always up-to-date. Alternatively you can add the file
> to your `.gitignore`, or you can remove the `generate_sdl_file` option to skip
> generating the file.

With the `generate_sdl_file` option, calls to `mix ash.codegen <name>` will generate
a `.graphql` file at the specified path.

## Generating on Recompilation


```elixir
use AshGraphql,
  domains: [Domain1, Domain2],
  generate_sdl_file: "priv/schema.graphql",
  auto_generate_sdl_file?: true
```

By specifying the `auto_generate_sdl_file?` option, the sdl file will be generated any time
the schema recompiles.

## Why generate the SDL file?

Some things that you can use this SDL file for:

### Documentation

The schema file itself represents your entire GraphQL API definition, and examining it can be very useful.

### Code Generation

You can use tools like [GraphQL codegen](https://the-guild.dev/graphql/codegen) to generate a client
for your GraphQL API.

### Validating Changes

Use the SDL file to check for breaking changes in your schema, especially if you are exposing a public API.
A plug and play github action for this can be found here: https://the-guild.dev/graphql/inspector/docs/products/action
