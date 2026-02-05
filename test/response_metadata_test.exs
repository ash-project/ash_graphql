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
               extensions: %{metadata: metadata}
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

      assert %{extensions: %{metadata: %{duration_ms: duration_ms}}} = result
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

      assert %{extensions: %{metadata: %{complexity: complexity}}} = result
      assert is_integer(complexity) or is_nil(complexity)
    end

    test "complexity is nil when analyze_complexity is not set" do
      query = """
      query {
        sayHello
      }
      """

      assert {:ok, result} = Absinthe.run(query, AshGraphql.Test.ResponseMetadata.Schema)

      assert %{extensions: %{metadata: %{complexity: complexity}}} = result
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
               extensions: %{metadata: metadata}
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
    test "existing extensions data is preserved when adding metadata" do
      blueprint = %Absinthe.Blueprint{
        operations: [
          %Absinthe.Blueprint.Document.Operation{
            current: true,
            name: "TestOp",
            type: :query,
            complexity: 42
          }
        ],
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
            metadata: %{existing_key: "existing_value"}
          }
        }
      }

      {:ok, result} =
        AshGraphql.Phase.InjectMetadata.run(blueprint,
          schema: AshGraphql.Test.ResponseMetadata.Schema
        )

      assert result.result.extensions.metadata[:existing_key] == "existing_value"
      assert Map.has_key?(result.result.extensions.metadata, :duration_ms)
      assert result.result.extensions.metadata[:complexity] == 42
      assert result.result.extensions.metadata[:operation_name] == "TestOp"
      assert result.result.extensions.metadata[:operation_type] == :query
    end
  end

  describe "response_metadata validation" do
    test "true is rejected and requires a key" do
      assert_raise ArgumentError, ~r/You must specify the key/, fn ->
        AshGraphql.validate_response_metadata!(true)
      end
    end

    test "atom key is accepted" do
      assert :ok = AshGraphql.validate_response_metadata!(:my_key)
    end

    test "key with custom handler tuple is accepted" do
      assert :ok = AshGraphql.validate_response_metadata!({:my_key, {MyModule, :my_function, []}})
    end

    test "false is accepted" do
      assert :ok = AshGraphql.validate_response_metadata!(false)
    end

    test "nil is accepted" do
      assert :ok = AshGraphql.validate_response_metadata!(nil)
    end

    test "invalid values are rejected" do
      assert_raise ArgumentError, ~r/Invalid `response_metadata` configuration/, fn ->
        AshGraphql.validate_response_metadata!("invalid")
      end

      assert_raise ArgumentError, ~r/Invalid `response_metadata` configuration/, fn ->
        AshGraphql.validate_response_metadata!({:key, :not_a_tuple})
      end
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
