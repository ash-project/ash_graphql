<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Custom Types

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
