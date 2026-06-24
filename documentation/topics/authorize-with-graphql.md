<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Authorize with GraphQL

AshGraphql uses three special keys in the `absinthe` context:

- `:actor` - the current actor, to be used for authorization/preparations/changes
- `:tenant` - a tenant when using [multitenancy](https://hexdocs.pm/ash/multitenancy.html).
- `:ash_context` - a map of arbitrary context to be passed into the changeset/query. Accessible via `changeset.context` and `query.context`

By default, `authorize?` in the domain is set to true. To disable authorization for a given domain in graphql, use:

```elixir
graphql do
  authorize? false
end
```

If you are doing authorization, you'll need to provide an `actor`.

### Using AshAuthentication

If you have not yet installed AshAuthentication, you can install it with igniter:

```bash
# installs ash_authentication & ash_authentication_phoenix
mix igniter.install ash_authentication_phoenix 
```

If you've already set up `AshGraphql` before adding `AshAuthentication`, you will 
just need to make sure that your `:graphql` scope in your router looks like this:

```elixir
pipeline :graphql do
  plug :load_from_bearer
  plug :set_actor, :user
  plug AshGraphql.Plug
end
```

### Using Something Else

To set the `actor` for authorization, you'll need to add an `actor` key to the
absinthe context. Typically, you would have a plug that fetches the current user and uses `Ash.PlugHelpers.set_actor/2` to set the actor in the `conn` (likewise with `Ash.PlugHelpers.set_tenant/2`).

Just add `AshGraphql.Plug` somewhere _after_ that in the pipeline and the your
GraphQL APIs will have the correct authorization.

```elixir
defmodule MyAppWeb.Router do
  pipeline :api do
    # ...
    plug :get_actor_from_token
    plug AshGraphql.Plug
  end

  scope "/" do
    forward "/gql", Absinthe.Plug, schema: YourSchema

    forward "/playground",
          Absinthe.Plug.GraphiQL,
          schema: YourSchema,
          interface: :playground
  end

  def get_actor_from_token(conn, _opts) do
     with ["" <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- MyApp.Guardian.resource_from_token(token) do
      conn
      |> set_actor(user)
    else
    _ -> conn
    end
  end
end
```

## Policy Breakdowns

By default, unauthorized requests simply return `forbidden` in the message. If you prefer to show policy breakdowns in your GraphQL errors, you can set the config option:

```elixir
config :ash_graphql, :policies, show_policy_breakdowns?: true
```

```json
{
  "data": {
    "attendanceRecords": null
  },
  "errors": [
    {
      "code": "forbidden",
      "fields": [],
      "locations": [
        {
          "column": 3,
          "line": 2
        }
      ],
      "message": "MyApp.Authentication.User.read\n\n\n\n\nPolicy Breakdown\n  Policy | ⛔:\n    forbid unless: actor is active | ✓ | ⬇    \n    authorize if: actor is Executive | ✘ | ⬇",
      "path": ["attendanceRecords"],
      "short_message": "forbidden",
      "vars": {}
    }
  ]
}
```

Be careful, as this can be an attack vector in some systems (i.e "here is exactly what you need to make true to do what you want to do").

## Field Policies

By default, field policies in AshGraphql work by producing a `null` value for any forbidden field, as well as an error in the errors list.

> ### nullability {: .warning}
>
> Any fields with field policies on them should be nullable. If they are not nullable, the _parent_ object will also be `null` (and considered in an error state), because `null` is not a valid type for that field.

To make specific fields nullable even if they are not nullable by definition, use the `nullable_fields` option.

```elixir
graphql do
  type :post

  nullable_fields [:foo, :bar, :baz]
end
```

To automatically make fields that may be hidden by authorization nullable, use `forbidden_field_mode :nullable`.
Built-in Ash field policies are detected automatically, excluding catch-all policies like `authorize_if always()`. Custom authorizers can participate by reporting the fields they may hide.

```elixir
graphql do
  type :post

  forbidden_field_mode :nullable
end
```

To expose forbidden fields as data instead of GraphQL errors, use `forbidden_field_mode :materialized`.
Fields that may be hidden by authorization are exposed as unions whose members are a field-specific value wrapper and `ForbiddenField`.
Singular relationships with `allow_forbidden_field? true` are exposed as unions whose members are the destination type and `ForbiddenField`.

```elixir
graphql do
  type :post

  forbidden_field_mode :materialized
end

relationships do
  belongs_to :organization, MyApp.Organization do
    public? true
    allow_forbidden_field? true
  end
end
```

### Relationships

Field policies cover attributes, calculations, and aggregates. They do not currently target relationships.

Singular relationships can still be materialized when Ash may return a forbidden relationship sentinel. To opt into that behavior, configure the relationship with `allow_forbidden_field? true` and use `forbidden_field_mode :materialized`.

```elixir
graphql do
  type :post
  forbidden_field_mode :materialized
end

relationships do
  belongs_to :organization, MyApp.Organization do
    public? true
    allow_nil? false
    allow_forbidden_field? true
  end
end
```

This exposes the singular relationship as a union of the destination type and `ForbiddenField`:

```graphql
type Post {
  organization: PostOrganizationRelationship!
}

union PostOrganizationRelationship = Organization | ForbiddenField
```

This only applies to singular relationships. List, paginated, and Relay connection relationships are not materialized as forbidden unions.
