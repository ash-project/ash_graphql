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

### Error handler in resources
Error handlers can also be specified in a resource. For examples:

```elixir
defmodule MyApp.Resource do
  use Ash.Resource,
    domain: [MyApp.Domain],
    extensions: [AshGraphql]
    
  graphql do
    type :ticket
    error_handler {MyApp.Resource.GraphqlErrorHandler, :handle_error, []}
  end
  
  # ...
end
```

If both an error handler for the resource and one for the domain are defined,
they both take action: first the resource handler and then the domain handler.

If an action on a resource calls other actions (e.g. with a
`manage_relationships`) the errors are handled by the primary resource that
called the action.

### Filtering by action

The error handler carries in the context the name of the primary action that
returned the error down the line. With that one can set different behaviors
depending on the specific action that triggered the error. For example consider
the following resource with `:create`, `:custom_create` and `:update` actions:

```elixir
defmodule MyApp.Resource do
  use Ash.Resource,
    domain: [MyApp.Domain],
    extensions: [AshGraphql]
    
  graphql do
    type :ticket
    error_handler {MyApp.Resource.GraphqlErrorHandler, :handle_error, []}
  end
  
  actions do
    deafults [:read, :destroy, :create]
    create :custom_create do
      # ...
      change manage_relationships # ...
    end
    
    update :update do
      # ...
    end
  end
end
```

The error handler `MyApp.Resource.GraphqlErrorHandler` can in this case set
different behaviors depending on the specific action that caused the error:

```elixir
defmodule MyApp.Resource.GraphqlErrorHandler do

  def handle_error(error, context) do
    %{action: action} = context

    case action do
      :custom_create -> custom_create_behavior(error)
      :update -> update_behavior(error)
      
      _ -> deafult_behvaior(error)
    end
  end
end
```

## Custom Errors

If you created your own Errors as described in the [Ash Docs](https://hexdocs.pm/ash/error-handling.html#using-a-custom-exception) you also need to implement
the protocol for it to be displayed in the Api.

```elixir
defmodule Ash.Error.Action.InvalidArgument do
  @moduledoc "Used when an invalid value is provided for an action argument"
  use Splode.Error, fields: [:field, :message, :value], class: :invalid

  def message(error) do
    """
    Invalid value provided#{for_field(error)}#{do_message(error)}

    #{inspect(error.value)}
    """
  end
  
  defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidArgument do
    def to_error(error) do
      %{
        message: error.message,
        short_message: error.message,
        code: "invalid_argument",
        vars: Map.new(error.vars),
        fields: [error.field]
      }
    end
  end
end
```
