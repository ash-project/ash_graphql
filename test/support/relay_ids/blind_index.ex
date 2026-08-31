# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.RelayIds.BlindIndex do
  @moduledoc """
  Test support for exposing a card number as a non-expression calculation while
  filtering it through a private blind index attribute.
  """

  use Ash.Resource.Calculation, type: :string

  require Ash.Expr
  import Ash.Expr

  @doc "Reveals the stored card number. Deliberately has no expression."
  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, & &1.stored_card_number)
  end

  @impl true
  def load(_query, _opts, _context), do: [:stored_card_number]

  @doc "Filter handler: hashes the GraphQL input and compares against the blind index attribute."
  def filter(hash_attribute, value, context) do
    case context.operator do
      :eq ->
        expr(^ref(hash_attribute) == ^hash(value))

      :in when is_list(value) ->
        expr(^ref(hash_attribute) in ^Enum.map(value, &hash/1))

      _ ->
        expr(false)
    end
  end

  @doc false
  def hash(value) when is_binary(value) do
    :sha256 |> :crypto.hash(value) |> Base.encode16(case: :lower)
  end

  def hash(value), do: value
end
