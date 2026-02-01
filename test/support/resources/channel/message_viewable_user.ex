# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.MessageViewableUser do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table(:message_user)
  end

  actions do
    default_accept(:*)
    defaults([:read, :update, :destroy])

    create :create do
      primary?(true)
    end
  end

  relationships do
    belongs_to(:message, AshGraphql.Test.Message,
      primary_key?: true,
      allow_nil?: false,
      attribute_writable?: true,
      public?: true
    )

    belongs_to(:user, AshGraphql.Test.User,
      primary_key?: true,
      allow_nil?: false,
      attribute_writable?: true,
      public?: true
    )
  end
end
