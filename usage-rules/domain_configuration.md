<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Domain Configuration

AshGraphql works by extending your Ash domains and resources with GraphQL capabilities. First, add the AshGraphql extension to your domain.

## Setting Up Your Domain

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

## Creating Your GraphQL Schema

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