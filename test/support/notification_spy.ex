# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.NotificationSpy do
  @moduledoc """
  Test notifier that captures raw Ash notifications for assertion.
  """
  use Ash.Notifier

  @impl true
  def notify(notification) do
    if pid = Application.get_env(:ash_graphql, :notification_spy_pid) do
      send(pid, {:ash_notification, notification})
    end

    :ok
  end
end
