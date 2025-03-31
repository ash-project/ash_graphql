defmodule AshGraphql.Test.Changes.CreateMessageUser do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, context) do
    changeset
    |> Ash.Changeset.after_action(fn _, result ->
      case AshGraphql.Test.MessageUser
           |> Ash.Changeset.for_create(:create, %{
             message_id: changeset.data.id,
             user_id: context.actor.id
           })
           |> Ash.create() do
        {:ok, _} ->
          {:ok, result}

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
