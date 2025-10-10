# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.ContextHelpers do
  @moduledoc "Helper to extract context from its various locations"

  def get_context(context) do
    case Map.get(context, :context) do
      nil ->
        case Map.get(context, :ash_context) do
          nil ->
            %{}

          context ->
            IO.warn(
              "Using `:ash_context` is deprecated, use `Ash.PlugHelpers.set_context/2` instead."
            )

            context
        end

      context ->
        context
    end
  end
end
