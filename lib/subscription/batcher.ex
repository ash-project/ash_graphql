defmodule AshGraphql.Subscription.Batcher do
  use GenServer

  alias Absinthe.Pipeline.BatchResolver

  require Logger
  @compile {:inline, simulate_slowness: 0}

  defstruct batches: %{}, total_count: 0, async_limit: 100, async_threshold: 50

  defmodule Batch do
    defstruct notifications: [], count: 0, pubsub: nil, key_strategy: nil, doc: nil, timer: nil

    def add(batch, item) do
      %{batch | notifications: [item | batch.notifications], count: batch.count + 1}
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def drain do
    GenServer.call(__MODULE__, :drain, :infinity)
  end

  def publish(topic, notification, pubsub, key_strategy, doc) do
    case GenServer.call(
           __MODULE__,
           {:publish, topic, notification, pubsub, key_strategy, doc},
           :infinity
         ) do
      :handled ->
        :ok

      :backpressure_sync ->
        do_send(topic, [notification], pubsub, key_strategy, doc)
    end
  end

  def init(config) do
    {:ok,
     %__MODULE__{
       async_limit: config[:async_limit] || 100,
       async_threshold: config[:async_threshold] || 50
     }}
  end

  def handle_call(:drain, _from, state) do
    {:reply, :done, send_all_batches(state)}
  end

  def handle_call(:dump_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:publish, topic, notification, pubsub, key_strategy, doc}, from, state) do
    simulate_slowness()

    if state.total_count >= state.async_limit do
      {:reply, :backpressure_sync, state}
    else
      GenServer.reply(from, :handled)
      simulate_slowness()
      state = put_notification(state, topic, pubsub, key_strategy, doc, notification)

      # if we have less than async threshold, we can process it eagerly
      if state.total_count < state.async_threshold do
        # so we eagerly process current_calls
        state = eagerly_build_batches(state, state.async_threshold - state.total_count)

        # and if we still have less than the async threshold
        if state.total_count < state.async_threshold do
          # then we send all of our batches
          {:noreply, send_all_batches(state)}
        else
          # otherwise we wait on the regularly scheduled push
          {:noreply, ensure_timer(state, topic)}
        end
      else
        # otherwise we wait on the regularly scheduled push
        {:noreply, ensure_timer(state, topic)}
      end
    end
  end

  def handle_info({_task, {:sent, topic, count, _res}}, state) do
    {:noreply,
     %{state | total_count: state.total_count - count, batches: Map.delete(state.batches, topic)}}
  end

  def handle_info({:send_batch, topic}, state) do
    batch = state.batches[topic]

    Task.async(fn ->
      {:sent, topic, batch.count,
       do_send(topic, batch.notifications, batch.pubsub, batch.key_strategy, batch.doc)}
    end)

    {:noreply, state}
  end

  defp eagerly_build_batches(state, 0), do: state

  defp eagerly_build_batches(state, count) do
    receive do
      {:"$gen_call", {:publish, topic, notification, pubsub, key_strategy, doc}, from} ->
        GenServer.reply(from, :handled)

        state
        |> put_notification(topic, pubsub, key_strategy, doc, notification)
        |> eagerly_build_batches(count - 1)
    after
      0 ->
        state
    end
  end

  if Application.compile_env(:ash_graphql, :simulate_subscription_slowness?, false) do
    defp simulate_slowness do
      :timer.sleep(Application.get_env(:ash_graphql, :simulate_subscription_processing_time, 0))
    end
  else
    defp simulate_slowness do
      :ok
    end
  end

  defp send_all_batches(state) do
    Enum.each(state.batches, fn {topic, batch} ->
      if batch.timer do
        Process.cancel_timer(batch.timer)
      end

      do_send(topic, batch.notifications, batch.pubsub, batch.key_strategy, batch.doc)
    end)

    %{state | batches: %{}, total_count: 0}
  end

  defp do_send(topic, notifications, pubsub, key_strategy, doc) do
    # Refactor to do batch resolution
    notifications
    |> Enum.reverse()
    |> Enum.each(fn notification ->
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
    end)
  end

  defp put_notification(state, topic, pubsub, key_strategy, doc, notification) do
    state.batches
    |> Map.put_new_lazy(topic, fn ->
      %Batch{key_strategy: key_strategy, doc: doc, pubsub: pubsub}
    end)
    |> Map.update!(topic, &Batch.add(&1, notification))
    |> then(&%{state | batches: &1, total_count: state.total_count + 1})
  end

  defp ensure_timer(%{batches: batches} = state, topic) do
    if batches[topic].timer do
      state
    else
      # TODO: this interval should be configurable
      timer = Process.send_after(self(), {:send_batch, topic}, 1000)

      put_in(state.batches[topic].timer, timer)
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
