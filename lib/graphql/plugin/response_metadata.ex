# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Plugin.ResponseMetadata do
  @moduledoc """
  Absinthe plugin that captures timing information and injects response metadata.

  ## Usage

  Add this plugin to your schema:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use AshGraphql, domains: [...], response_metadata: true

        def plugins do
          [AshGraphql.Plugin.ResponseMetadata | Absinthe.Plugin.defaults()]
        end
      end
  """

  @behaviour Absinthe.Plugin

  @impl Absinthe.Plugin
  def before_resolution(execution) do
    acc =
      execution.acc
      |> Map.put_new(:ash_graphql, %{})
      |> update_in([:ash_graphql], &Map.put_new(&1, :start_time, System.monotonic_time()))

    %{execution | acc: acc}
  end

  @impl Absinthe.Plugin
  def after_resolution(execution) do
    end_time = System.monotonic_time()

    acc =
      execution.acc
      |> Map.put_new(:ash_graphql, %{})
      |> put_in([:ash_graphql, :end_time], end_time)

    %{execution | acc: acc}
  end

  @impl Absinthe.Plugin
  def pipeline(pipeline, execution) do
    schema = execution.schema

    if function_exported?(schema, :response_metadata, 0) && schema.response_metadata() do
      [{AshGraphql.Phase.InjectMetadata, schema: schema} | pipeline]
    else
      pipeline
    end
  end
end
