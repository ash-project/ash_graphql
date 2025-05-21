# Rules for working with AshGraphql

## Understanding AshGraphql

AshGraphql is a package for integrating Ash Framework with GraphQL. It provides tools for generating GraphQL types, queries, mutations, and subscriptions from your Ash resources. AshGraphql leverages Absinthe under the hood to create a seamless integration between your Ash resources and GraphQL API.

## Domain Configuration

AshGraphql works by extending your Ash domains and resources with GraphQL capabilities. First, add the AshGraphql extension to your domain.

### Setting Up Your Domain

```elixir
defmodule MyApp.Blog do
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  graphql do
    # Define GraphQL-specific settings for this domain
    authorize? true

    # Add GraphQL queries separate from the resource config
    queries do
      get Post, :get_post, :read
      list Post, :list_posts, :read
    end

    # Add GraphQL mutations separate from the resource config
    mutations do
      create Post, :create_post, :create
      update Post, :update_post, :update
      destroy Post, :destroy_post, :destroy
    end

    # Add GraphQL subscriptions
    subscriptions do
      subscribe Post, :post_created do
        action_types(:create)
      end
    end
  end

  resources do
    resource MyApp.Blog.Post
    resource MyApp.Blog.Comment
  end
end
```

### Creating Your GraphQL Schema

Create an Absinthe schema that uses your Ash domains:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  # List all domains that contain resources to expose via GraphQL
  @domains [MyApp.Blog, MyApp.Accounts]

  # Configure AshGraphql with your domains
  use AshGraphql,
    domains: @domains,
    # Generate SDL file (optional)
    generate_sdl_file: "schema.graphql"
end
```

## Resource Configuration

Each resource that you want to expose via GraphQL needs to include the AshGraphql.Resource extension.

### Setting Up Resources

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    extensions: [AshGraphql.Resource]

  attributes do
    uuid_primary_key :id
    attribute :title, :string
    attribute :body, :string
    attribute :published, :boolean
    attribute :view_count, :integer
  end

  relationships do
    belongs_to :author, MyApp.Accounts.User
    has_many :comments, MyApp.Blog.Comment
  end

  graphql do
    # The GraphQL type name (required)
    type :post

    # Customize attribute types for GraphQL
    attribute_types view_count: :string

    # Configure managed relationships (for nested create/update)
    managed_relationships do
      managed_relationship :with_comments, :comments
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :list_published do
      filter expr(published == true)
    end

    update :publish do
      accept []
      change set_attribute(:published, true)
    end
  end
end
```

## Custom Types

AshGraphql automatically handles conversion of Ash types to GraphQL types, but you can customize it:

```elixir
defmodule MyApp.CustomType do
  use Ash.Type

  @impl true
  def graphql_type(_), do: :string

  @impl true
  def graphql_input_type(_), do: :string
end
```
