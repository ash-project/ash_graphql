# Handling Errors

There are various options that can be set on the Domain module to determine how errors behave and/or are shown in the GraphQL.

## Showing raised errors

For security purposes, if an error is *raised* as opposed to returned somewhere, the error is hidden. Set this to `true` in dev/test environments for an easier time debugging.

```elixir
graphql do
  show_raised_errors? true
end

# or it can be done in config
# make sure you've set `otp_app` in your domain, i.e use Ash.Domain, otp_app: :my_app

config :my_app, YourDomain, [
  graphql: [
    show_raised_errors?: true
  ]
]
```

## Root level errors

By default, action errors are simply shown in the `errors` field for mutations. Set this to `true` to return them as root level errors instead.

```elixir
graphql do
  root_level_errors? true
end
```

## Error Handler

Setting an error handler allows you to use things like `gettext` to translate errors and/or modify errors in some way. This error handler will take the error object to be returned, and the context. See the [absinthe docs](https://hexdocs.pm/absinthe/context-and-authentication.html#context-and-plugs) for adding to the absinthe context (i.e for setting a locale).

```elixir
graphql do
  error_handler {MyApp.GraphqlErrorHandler, :handle_error, []}
end
```

Keep in mind, that you will want to ensure that any custom error handler you add performs the logic to replace variables in error messages. 

This is what the default error handler looks like, for example:

```elixir
defmodule AshGraphql.DefaultErrorHandler do
  @moduledoc "Replaces any text in message or short_message with variables"

  def handle_error(
        %{message: message, short_message: short_message, vars: vars} = error,
        _context
      ) do
    %{
      error
      | message: replace_vars(message, vars),
        short_message: replace_vars(short_message, vars)
    }
  end

  def handle_error(other, _), do: other

  defp replace_vars(string, vars) do
    vars =
      if is_map(vars) do
        vars
      else
        List.wrap(vars)
      end

    Enum.reduce(vars, string, fn {key, value}, acc ->
      if String.contains?(acc, "%{#{key}}") do
        String.replace(acc, "%{#{key}}", to_string(value))
      else
        acc
      end
    end)
  end
end
```