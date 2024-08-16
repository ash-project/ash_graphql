# Using the SDL File

By passing the `generate_sdl_file` to `use AshGraphql.Schema`, AshGraphql will generate
a schema file when you run `mix ash.codegen`.

> ### Ensure your schema is up to date, gitignored, or not generated {: .info}
>
> We suggest first adding `mix ash.codegen --check` to your CI/CD pipeline to
> ensure the schema is always up-to-date. Alternatively you can add the file
> to your `.gitignore`, or you can remove the `generate_sdl_file` option to skip
> generating the file.

Some things that you can use this SDL file for:

## Documentation

The schema file itself represents your entire GraphQL API definition, and examining it can be very useful.

## Code Generation

You can use tools like [GraphQL codegen](https://the-guild.dev/graphql/codegen) to generate a client
for your GraphQL API.

## Validating Changes

Use the SDL file to check for breaking changes in your schema, especially if you are exposing a public API.
A plug and play github action for this can be found here: https://the-guild.dev/graphql/inspector/docs/products/action
