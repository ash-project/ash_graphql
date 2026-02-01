# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ForceChangeId do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, _) do
    case Ash.Changeset.fetch_argument(changeset, :id) do
      {:ok, id} ->
        Ash.Changeset.force_change_attribute(changeset, :id, id)

      :error ->
        changeset
    end
  end
end
