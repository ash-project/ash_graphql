# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.ResponseMetadataTest do
  use ExUnit.Case, async: true

  describe "response metadata with default handler" do
    test "metadata appears in extensions when enabled" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} = Absinthe.run(query, AshGraphql.Test.ResponseMetadata.Schema)

      assert %{
               data: %{"sayHello" => "Hello!"},
               extensions: %{ash: metadata}
             } = result

      assert is_map(metadata)
      assert Map.has_key?(metadata, :duration_ms)
    end

    test "duration is a positive integer" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} = Absinthe.run(query, AshGraphql.Test.ResponseMetadata.Schema)

      assert %{extensions: %{ash: %{duration_ms: duration_ms}}} = result
      assert is_integer(duration_ms)
      assert duration_ms >= 0
    end

    test "complexity is calculated when analyze_complexity is true" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} =
               Absinthe.run(query, AshGraphql.Test.ResponseMetadata.Schema,
                 analyze_complexity: true
               )

      assert %{extensions: %{ash: %{complexity: complexity}}} = result
      assert is_integer(complexity) or is_nil(complexity)
    end

    test "complexity is nil when analyze_complexity is not set" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} = Absinthe.run(query, AshGraphql.Test.ResponseMetadata.Schema)

      assert %{extensions: %{ash: %{complexity: complexity}}} = result
      assert is_nil(complexity)
    end
  end

  describe "response metadata with custom handler" do
    test "custom metadata handler is called" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} =
               Absinthe.run(query, AshGraphql.Test.ResponseMetadata.CustomHandlerSchema)

      assert %{
               data: %{"sayHello" => "Hello!"},
               extensions: %{ash: metadata}
             } = result

      assert metadata[:custom_field] == "custom_value"
      assert Map.has_key?(metadata, :duration_ms)
      assert Map.has_key?(metadata, :complexity)
    end
  end

  describe "response metadata when disabled" do
    test "no extensions when response_metadata is false" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} =
               Absinthe.run(query, AshGraphql.Test.ResponseMetadata.DisabledSchema)

      assert %{data: %{"sayHello" => "Hello!"}} = result
      refute Map.has_key?(result, :extensions)
    end
  end

  describe "plugin behavior" do
    test "start_time is not overwritten on multiple before_resolution calls" do
      execution = %{acc: %{}}

      execution1 = AshGraphql.Plugin.ResponseMetadata.before_resolution(execution)
      original_start_time = execution1.acc.ash_graphql.start_time

      Process.sleep(1)

      execution2 = AshGraphql.Plugin.ResponseMetadata.before_resolution(execution1)

      assert execution2.acc.ash_graphql.start_time == original_start_time
    end

    test "end_time is always updated on after_resolution calls" do
      execution = %{acc: %{ash_graphql: %{}}}

      execution1 = AshGraphql.Plugin.ResponseMetadata.after_resolution(execution)
      first_end_time = execution1.acc.ash_graphql.end_time

      Process.sleep(1)

      execution2 = AshGraphql.Plugin.ResponseMetadata.after_resolution(execution1)
      second_end_time = execution2.acc.ash_graphql.end_time

      assert second_end_time > first_end_time
    end
  end

  describe "extensions merging" do
    test "existing extensions.ash data is preserved when adding metadata" do
      blueprint = %Absinthe.Blueprint{
        execution: %Absinthe.Blueprint.Execution{
          acc: %{
            ash_graphql: %{
              start_time: System.monotonic_time() - 1_000_000,
              end_time: System.monotonic_time()
            }
          },
          result: %{
            emitter: nil
          }
        },
        result: %{
          extensions: %{
            ash: %{existing_key: "existing_value"}
          }
        }
      }

      {:ok, result} =
        AshGraphql.Phase.InjectMetadata.run(blueprint,
          schema: AshGraphql.Test.ResponseMetadata.Schema
        )

      assert result.result.extensions.ash[:existing_key] == "existing_value"
      assert Map.has_key?(result.result.extensions.ash, :duration_ms)
    end
  end

  describe "response metadata error handling" do
    import ExUnit.CaptureLog

    test "custom handler that raises exception logs warning and omits metadata" do
      query = """
      query {
        sayHello
      }
      """

      log =
        capture_log(fn ->
          assert {:ok, result} =
                   Absinthe.run(query, AshGraphql.Test.ResponseMetadata.RaisingHandlerSchema)

          assert %{data: %{"sayHello" => "Hello!"}} = result
          refute Map.has_key?(result, :extensions)
        end)

      assert log =~ "AshGraphql response_metadata handler"
      assert log =~ "raised:"
      assert log =~ "Intentional error for testing"
    end

    test "custom handler returning empty map does not add extensions" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} =
               Absinthe.run(query, AshGraphql.Test.ResponseMetadata.EmptyMapHandlerSchema)

      assert %{data: %{"sayHello" => "Hello!"}} = result
      refute Map.has_key?(result, :extensions)
    end

    test "custom handler returning non-map value logs warning and omits metadata" do
      query = """
      query {
        sayHello
      }
      """

      log =
        capture_log(fn ->
          assert {:ok, result} =
                   Absinthe.run(query, AshGraphql.Test.ResponseMetadata.NonMapHandlerSchema)

          assert %{data: %{"sayHello" => "Hello!"}} = result
          refute Map.has_key?(result, :extensions)
        end)

      assert log =~ "AshGraphql response_metadata handler"
      assert log =~ "expected a map or nil"
    end
  end
end
