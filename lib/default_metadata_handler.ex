# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.DefaultMetadataHandler do
  @moduledoc """
  Default handler for building response metadata.

  Returns complexity and duration_ms in the response extensions.
  """

  def build_metadata(info) do
    %{
      complexity: info.complexity,
      duration_ms: info.duration_ms,
      operation_name: info.operation_name,
      operation_type: info.operation_type
    }
  end
end
