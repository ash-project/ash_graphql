# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Status do
  @moduledoc false
  use Ash.Type

  @values [:open, :closed]
  @string_values Enum.map(@values, &to_string/1)

  def graphql_input_type(_), do: :status
  def graphql_type(_), do: :status

  @impl true
  def storage_type, do: :string

  @impl true
  def cast_input(value, _) when value in @values do
    {:ok, value}
  end

  def cast_input(value, _) when is_binary(value) do
    value = String.downcase(value)

    if value in @string_values do
      {:ok, String.to_existing_atom(value)}
    else
      :error
    end
  end

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) when value in @values do
    {:ok, value}
  end

  def cast_stored(value, _) when value in @string_values do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError ->
      :error
  end

  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(value, _) when is_atom(value) do
    {:ok, to_string(value)}
  end

  def dump_to_native(_, _), do: :error
end
