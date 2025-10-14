# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Graphql.IdTranslator do
  @moduledoc false

  def translate_relay_ids(%{state: :unresolved} = resolution, relay_id_translations) do
    arguments =
      Enum.reduce(relay_id_translations, resolution.arguments, &process/2)

    %{resolution | arguments: arguments}
  end

  def translate_relay_ids(resolution, _relay_id_translations) do
    resolution
  end

  defp process({field, nested_translations}, args) when is_list(nested_translations) do
    case Map.get(args, field) do
      subtree when is_map(subtree) ->
        new_subtree = Enum.reduce(nested_translations, subtree, &process/2)
        Map.put(args, field, new_subtree)

      elements when is_list(elements) ->
        new_elements =
          Enum.map(elements, fn element ->
            Enum.reduce(nested_translations, element, &process/2)
          end)

        Map.put(args, field, new_elements)

      _ ->
        args
    end
  end

  defp process({field, type}, args) when is_atom(type) do
    case Map.get(args, field) do
      id when is_binary(id) ->
        case AshGraphql.Resource.decode_relay_id(id) do
          {:ok, %{type: ^type, id: decoded_id}} ->
            Map.put(args, field, decoded_id)

          _ ->
            # If we fail to decode for the correct type, we just skip translation
            # This will be marked as an invalid input down the line
            args
        end

      [id | _] = ids when is_binary(id) ->
        decoded_ids =
          Enum.map(ids, fn id ->
            case AshGraphql.Resource.decode_relay_id(id) do
              {:ok, %{type: ^type, id: decoded_id}} ->
                decoded_id

              _ ->
                # If we fail to decode for the correct type, we just skip translation
                # This will be marked as an invalid input down the line
                id
            end
          end)

        Map.put(args, field, decoded_ids)

      _ ->
        args
    end
  end
end
