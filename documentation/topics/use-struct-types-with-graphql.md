# Use Struct Types with GraphQL

When you need to pass structured data as standalone arguments (not creating relationships), custom struct types provide structured GraphQL input validation instead of generic JSON strings.

## When You Need This

**Relationship arguments** automatically get structured inputs:
```elixir
# ✅ Gets structured CreateAddressInput automatically
argument :address, :map
change manage_relationship(:address, type: :direct_control)
```

**Standalone data arguments** fall back to JsonString:
```elixir
# ❌ Becomes JsonString! (no structure validation)
argument :metadata, :map  # Just passing data, not creating a relationship
```

Custom struct types solve this by providing structured validation for standalone data arguments.

## Creating Custom Struct Types

To get structured GraphQL input types for standalone data arguments, create a custom type that references an existing resource's input schema.

### Step 1: Create a custom type

## Choosing Your Approach

**For new standalone data structures:**

```elixir
defmodule MyApp.Types.TicketMetadataType do
  use Ash.TypedStruct

  typed_struct do
    field :priority, :string, allow_nil?: false
    field :category, :string, allow_nil?: false
    field :tags, {:array, :string}, allow_nil?: true
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :ticket_metadata

  @impl true
  def graphql_input_type(_), do: :create_ticket_metadata_input
end
```

**For referencing existing resource structures:**

```elixir
defmodule MyApp.Types.TicketMetadataType do
  use Ash.Type.NewType,
    subtype_of: :struct,
    constraints: [
      instance_of: MyApp.TicketMetadata
    ]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :ticket_metadata

  @impl true
  def graphql_input_type(_), do: :create_ticket_metadata_input
end
```

## Comparison

| Aspect | Ash.TypedStruct | Ash.Type.NewType + instance_of |
|--------|-----------------|--------------------------------|
| **Best for** | New standalone structures | Referencing existing resources |
| **Field definition** | Manual field declarations | Automatic from target resource |
| **Type safety** | Constructor functions (`new/1`, `new!/1`) | Inherits from target resource |
| **Validation** | Custom field constraints | Resource's existing validations |
| **Maintenance** | Fields must be kept in sync manually | Automatically syncs with resource changes |
| **DRY principle** | Duplicates field definitions | References single source of truth |
| **Flexibility** | Full control over structure | Constrained by target resource |

### Step 2: Use the custom type in your resource

```elixir
defmodule MyApp.Ticket do
  # ...
  
  actions do
    action :add_metadata do
      argument :metadata, MyApp.Types.TicketMetadataType,
        allow_nil?: false
    end
  end
end
```

## Result: Structured Input Types

```graphql
input AddMetadataInput {
  metadata: CreateTicketMetadataInput!  # Structured input
}

input CreateTicketMetadataInput {
  priority: String!
  category: String!
  tags: [String!]
}
```

## Troubleshooting

**Input still shows JsonString?**
- Verify `graphql_input_type` points to existing input type (e.g., `:create_ticket_metadata_input`)
- Ensure target resource has GraphQL mutations defined (creates the input type)
- Regenerate schema with `mix ash.codegen`

**Using `:struct` with `instance_of` directly?**
Raw struct constraints also fall back to JsonString for standalone arguments:

```elixir
# This also generates JsonString! for standalone arguments
argument :metadata, :struct,
  constraints: [instance_of: MyApp.TicketMetadata]
```

Use the custom type approach instead for structured validation.

**Target resource has no mutations?**
The target resource needs GraphQL mutations to provide input types to reference:

```elixir
defmodule MyApp.TicketMetadata do
  # ...
  
  graphql do
    type :ticket_metadata
    
    mutations do
      create :create_ticket_metadata, :create
    end
  end
end
```

**Schema not updating?**
- Run `mix ash.codegen` to regenerate GraphQL schema
- In test environment, use `MIX_ENV=test mix ash.codegen`