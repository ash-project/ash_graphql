# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Types.JSONString do
  @moduledoc """
  The Json scalar type allows arbitrary JSON values to be passed in and out.
  """
  use Absinthe.Schema.Notation

  scalar :json_string, name: "JsonString" do
    description("""
    The `Json` scalar type represents arbitrary json string data, represented as UTF-8
    character sequences. The Json type is most often used to represent a free-form
    human-readable json string.
    """)

    serialize(&encode/1)
    parse(&decode/1)
  end

  def decode(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, result} -> {:ok, result}
      _ -> :error
    end
  end

  def decode(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  def decode(_) do
    :error
  end

  def encode(nil), do: nil
  def encode(value), do: Jason.encode!(value)
end
