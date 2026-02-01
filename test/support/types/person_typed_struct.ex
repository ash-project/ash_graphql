# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.PersonTypedStructData do
  @moduledoc false

  use Ash.TypedStruct

  typed_struct do
    field(:name, :string, allow_nil?: false)
    field(:age, :integer, allow_nil?: true)
    field(:email, :string, allow_nil?: true)
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :person_type

  @impl true
  def graphql_input_type(_), do: :person_input_type
end
