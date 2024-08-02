defmodule AshGraphql.DefaultErrorHandler do
  @moduledoc "Replaces any text in message or short_message with variables"

  def handle_error(
        %{message: message, short_message: short_message, vars: vars} = error,
        _context
      ) do
    %{
      error
      | message: replace_vars(message, vars),
        short_message: replace_vars(short_message, vars)
    }
  end

  def handle_error(other, _), do: other

  defp replace_vars(string, vars) do
    vars =
      if is_map(vars) do
        vars
      else
        List.wrap(vars)
      end

    Enum.reduce(vars, string, fn {key, value}, acc ->
      if String.contains?(acc, "%{#{key}}") do
        String.replace(acc, "%{#{key}}", stringified_value(value))
      else
        acc
      end
    end)
  end

  def stringified_value(value) when is_list(value), do: "[#{value |> Enum.map(&stringified_value(&1)) |> Enum.join(", ")}]"
  def stringified_value(value), do: to_string(value)
end
