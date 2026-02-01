# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule GF.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(GF.Event)
    resource(GF.Attendee)
    resource(GF.Group)
    resource(GF.Member)
  end
end
