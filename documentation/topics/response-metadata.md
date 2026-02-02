<!--
SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Response Metadata

AshGraphql can inject execution metadata into the `extensions.ash` field of GraphQL responses, providing information about timing and query complexity.

## Setup

Two steps are required:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  use AshGraphql,
    domains: [MyApp.Domain],
    response_metadata: true

  def plugins do
    [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
  end

  query do
    # ...
  end
end
```

This produces responses like:

```json
{
  "data": { "users": [...] },
  "extensions": {
    "ash": {
      "complexity": 10,
      "duration_ms": 42,
      "operation_name": "GetUsers",
      "operation_type": "query"
    }
  }
}
```

## Configuration

| `response_metadata` value | Behavior |
|---------------------------|----------|
| `true` | Uses default handler |
| `false` or `nil` | Disabled (default) |
| `{Module, :function, args}` | Custom handler |

## Default Metadata Fields

When using `response_metadata: true`, these fields are included:

- **`complexity`** - Query complexity (requires `analyze_complexity: true`)
- **`duration_ms`** - Execution time in milliseconds
- **`operation_name`** - The GraphQL operation name, if provided
- **`operation_type`** - `:query`, `:mutation`, or `:subscription`

## Custom Handler

Provide an MFA tuple to customize the metadata:

```elixir
use AshGraphql,
  domains: [MyApp.Domain],
  response_metadata: {__MODULE__, :build_metadata, []}

def build_metadata(info) do
  %{
    duration_ms: info.duration_ms,
    request_id: Logger.metadata()[:request_id]
  }
end
```

The handler receives an `info` map with keys `:complexity`, `:duration_ms`, `:operation_name`, and `:operation_type`. It must return:

- A map to include in `extensions.ash`
- `nil` to omit metadata entirely

If the handler raises an exception or returns an invalid value, a warning is logged and the request completes without metadata.

## Complexity

Complexity requires Absinthe's analysis to be enabled:

```elixir
Absinthe.run(query, MyApp.Schema, analyze_complexity: true)

# Or in your router:
forward "/graphql", Absinthe.Plug,
  schema: MyApp.Schema,
  analyze_complexity: true
```

Without this option, the `complexity` field will be `nil`.

## Troubleshooting

**Metadata not appearing in responses**

Ensure both pieces are configured:
1. `response_metadata` is set in your `use AshGraphql` call
2. `AshGraphql.Plugin.ResponseMetadata` is in your `plugins/0` function

**Warning about missing start_time**

The plugin isn't being invoked. Verify it's first in your plugins list:

```elixir
def plugins do
  [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
end
```

**Complexity is always nil**

Enable complexity analysis in Absinthe options (see Complexity section above).
