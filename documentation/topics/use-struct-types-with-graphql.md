# Use Struct Types with GraphQL

Custom struct types provide structured GraphQL input validation for standalone data arguments instead of generic JSON strings.

## The Problem

Relationship arguments automatically get structured inputs, but standalone data arguments default to JsonString:

```elixir
# Relationship: Gets structured CreateAddressInput
argument :address, :map
change manage_relationship(:address, type: :direct_control)

# Standalone data: Becomes JsonString (no validation)
argument :metadata, :map
```

## Solution: Custom Struct Types

### Using Ash.TypedStruct (new structures)

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

### Using NewType (reference existing resources)

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

**Key Differences:**
- **TypedStruct**: Define fields manually, full control, requires manual sync
- **NewType**: Auto-inherits from resource, stays in sync, less flexible

### Use in your resource

```elixir
defmodule MyApp.Ticket do
  actions do
    action :add_metadata do
      argument :metadata, MyApp.Types.TicketMetadataType,
        allow_nil?: false
    end
  end
end
```

## Result

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

## Common Issues & Solutions

**Still seeing JsonString?**
1. Ensure `graphql_input_type` references an existing input type
2. Target resource must have GraphQL mutations defined:
   ```elixir
   graphql do
     mutations do
       create :create_ticket_metadata, :create
     end
   end
   ```
3. Run `mix ash.codegen` to regenerate schema

**Note:** Using `:struct` with `instance_of` directly also falls back to JsonString when used as an input. Always wrap in a custom type for structured validation.