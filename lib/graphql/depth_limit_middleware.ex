# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Graphql.DepthLimitMiddleware do
  # Refuses a root field whose selection nests more relationships than the
  # resource's `depth_limit`. Only relationship fields count, so page wrappers,
  # mutation results, embeds and calculations don't add depth.
  @moduledoc false

  alias Absinthe.Blueprint.Document.{Field, Fragment}

  def check_depth(%Absinthe.Resolution{state: :resolved} = resolution, _), do: resolution

  def check_depth(%{definition: definition, fragments: fragments} = resolution, depth_limit) do
    if too_deep?(definition.selections, depth_limit, fragments) do
      error =
        Ash.Error.Query.InvalidQuery.exception(
          message: "Query nests relationships deeper than the depth limit of #{depth_limit}"
        )

      Absinthe.Resolution.put_result(
        resolution,
        AshGraphql.Graphql.Resolver.to_resolution(
          {:error, error},
          resolution.context,
          resolution.context[:domain]
        )
      )
    else
      resolution
    end
  end

  defp too_deep?(selections, remaining, fragments) do
    Enum.any?(selections, fn
      %{flags: %{skip: _}} ->
        false

      %Field{schema_node: schema_node, selections: selections} ->
        if relationship_field?(schema_node) do
          remaining == 0 or too_deep?(selections, remaining - 1, fragments)
        else
          too_deep?(selections, remaining, fragments)
        end

      %Fragment.Inline{selections: selections} ->
        too_deep?(selections, remaining, fragments)

      %Fragment.Spread{name: name} ->
        too_deep?(Map.fetch!(fragments, name).selections, remaining, fragments)
    end)
  end

  defp relationship_field?(%Absinthe.Type.Field{} = field),
    do: Absinthe.Type.meta(field, :ash_relationship) == true

  defp relationship_field?(_), do: false
end
