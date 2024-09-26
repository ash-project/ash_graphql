defmodule AshGraphql.Subscription.Runner do
  @moduledoc """
  Custom implementation if the run_docset function for the PubSub module used for Subscriptions

  Mostly a copy of https://github.com/absinthe-graphql/absinthe/blob/3d0823bd71c2ebb94357a5588c723e053de8c66a/lib/absinthe/subscription/local.ex#L40
  but this lets us decide if we want to send the data to the client or not in certain error cases
  """
  alias Absinthe.Pipeline.BatchResolver

  require Logger

  def run_docset(pubsub, docs_and_topics, notification) do
    for {topic, key_strategy, doc} <- docs_and_topics do
      try do
        pipeline =
          Absinthe.Subscription.Local.pipeline(doc, notification)

        {:ok, %{result: data}, _} = Absinthe.Pipeline.run(doc.source, pipeline)

        Logger.debug("""
        Absinthe Subscription Publication
        Field Topic: #{inspect(key_strategy)}
        Subscription id: #{inspect(topic)}
        Data: #{inspect(data)}
        """)

        case should_send?(data) do
          false ->
            :ok

          true ->
            :ok = pubsub.publish_subscription(topic, data)
        end
      rescue
        e ->
          BatchResolver.pipeline_error(e, __STACKTRACE__)
      end
    end
  end

  defp should_send?(%{errors: errors}) do
    # if the user is not allowed to see the data or the query didn't
    # return any data we do not send the error to the client
    # because it would just expose unnecessary information
    # and the user can not really do anything usefull with it
    not (errors
         |> List.wrap()
         |> Enum.any?(fn error -> Map.get(error, :code) in ["forbidden", "not_found", nil] end))
  end

  defp should_send?(_), do: true
end
