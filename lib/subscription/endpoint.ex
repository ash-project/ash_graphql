defmodule AshGraphql.Subscription.Endpoint do
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Phoenix.Endpoint

      alias Absinthe.Pipeline.BatchResolver

      require Logger

      def run_docset(pubsub, docs_and_topics, mutation_result) do
        dbg(mutation_result, structs: false)

        for {topic, key_strategy, doc} <- docs_and_topics do
          try do
            pipeline =
              Absinthe.Subscription.Local.pipeline(doc, mutation_result.data)
              # why though?
              |> List.flatten()
              |> Absinthe.Pipeline.insert_before(
                Absinthe.Phase.Document.OverrideRoot,
                {Absinthe.Phase.Document.Context, context: %{ash_filter: get_filter(topic)}}
              )

            {:ok, %{result: data}, _} = Absinthe.Pipeline.run(doc.source, pipeline)

            Logger.debug("""
            Absinthe Subscription Publication
            Field Topic: #{inspect(key_strategy)}
            Subscription id: #{inspect(topic)}
            Data: #{inspect(data)}
            """)

            case is_forbidden(data) do
              true ->
                # do not send anything to the client if he is not allowed to see it
                :ok

              false ->
                :ok = pubsub.publish_subscription(topic, data)
            end
          rescue
            e ->
              BatchResolver.pipeline_error(e, __STACKTRACE__)
          end
        end
      end

      defp is_forbidden(%{errors: errors}) do
        errors
        |> List.wrap()
        |> Enum.any?(fn error -> Map.get(error, :code) in ["forbidden", "not_found"] end)
      end

      defp is_forbidden(_), do: false

      defp get_filter(topic) do
        [_, rest] = String.split(topic, "__absinthe__:doc:")
        [filter, _] = String.split(rest, ":")

        case Base.decode64(filter) do
          {:ok, filter} ->
            :erlang.binary_to_term(filter)

          _ ->
            nil
        end
      rescue
        _ -> nil
      end
    end
  end
end
