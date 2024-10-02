defmodule AshGraphql.Subscription.Batcher do
  use GenServer

  alias Absinthe.Pipeline.BatchResolver

  require Logger
  @compile {:inline, simulate_slowness: 0}

  defstruct batches: %{}, total_count: 0, async_limit: 100, send_immediately_threshold: 50

  defmodule Batch do
    defstruct notifications: [],
              count: 0,
              pubsub: nil,
              key_strategy: nil,
              doc: nil,
              timer: nil,
              task: nil

    def add(batch, item) do
      %{batch | notifications: [item | batch.notifications], count: batch.count + 1}
    end
  end

  def start_link(opts \\ []) do
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
       send_immediately_threshold: config[:send_immediately_threshold] || 50
     }}
  end

  def handle_call(:drain, _from, state) do
    {:reply, :done, send_all_batches(state, false)}
  end

  def handle_call(:dump_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:publish, topic, notification, pubsub, key_strategy, doc}, _from, state) do
    if state.total_count >= state.async_limit do
      {:reply, :backpressure_sync, state}
    else
      {:reply, :handled, state,
       {:continue, {:publish, topic, notification, pubsub, key_strategy, doc}}}
    end
  end

  def handle_continue({:publish, topic, notification, pubsub, key_strategy, doc}, state) do
    state = put_notification(state, topic, pubsub, key_strategy, doc, notification)

    # if we have less than async threshold, we can process it eagerly
    if state.total_count < state.send_immediately_threshold do
      # so we eagerly process current_calls
      state = eagerly_build_batches(state, state.send_immediately_threshold - state.total_count)

      # and if we still have less than the async threshold
      if state.total_count < state.send_immediately_threshold do
        # then we send all of our batches
        {:noreply, send_all_batches(state, true)}
      else
        # otherwise we wait on the regularly scheduled push
        {:noreply, ensure_timer(state, topic)}
      end
    else
      # otherwise we wait on the regularly scheduled push
      {:noreply, ensure_timer(state, topic)}
    end
  end

  def handle_info({_task, {:sent, topic, _res}}, state) do
    case state.batches[topic] do
      %{timer: timer} when not is_nil(timer) ->
        Process.cancel_timer(timer)

      _ ->
        :ok
    end

    {:noreply,
     %{
       state
       | total_count: state.total_count - Map.get(state.batches[topic] || %{}, :count, 0),
         batches: Map.delete(state.batches, topic)
     }}
  end

  def handle_info({:DOWN, _, _, _, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:send_batch, topic}, state) do
    batch = state.batches[topic]

    if batch do
      task =
        Task.async(fn ->
          {:sent, topic,
           do_send(topic, batch.notifications, batch.pubsub, batch.key_strategy, batch.doc)}
        end)

      {:noreply, put_in(state.batches[topic].task, task)}
    else
      {:noreply, state}
    end
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

  defp send_all_batches(state, async?) do
    state.batches
    |> Enum.reject(fn {_, batch} ->
      batch.task
    end)
    |> Enum.reduce(state, fn {topic, batch}, state ->
      if batch.timer do
        Process.cancel_timer(batch.timer)
      end

      if async? do
        task =
          Task.async(fn ->
            {:sent, topic,
             do_send(topic, batch.notifications, batch.pubsub, batch.key_strategy, batch.doc)}
          end)

        put_in(state.batches[topic].task, task)
      else
        do_send(topic, batch.notifications, batch.pubsub, batch.key_strategy, batch.doc)

        %{
          state
          | batches: Map.delete(state.batches, topic),
            total_count: state.total_count - batch.count
        }
      end
    end)
  end

  defp do_send(topic, notifications, pubsub, key_strategy, doc) do
    # This is a temporary and very hacky way of doing this
    # we pass in the notifications as a list as the root data
    # The resolver then returns the *first* one, and puts a list
    # of notifications in the process dictionary. Those will be
    # passed in *again* to the resolution step, to be returned
    # as-is. Its gross, and I hate it, but it is better than forcing
    # individual resolution :)

    simulate_slowness()

    pipeline =
      Absinthe.Subscription.Local.pipeline(doc, notifications)

    first_results =
      case Absinthe.Pipeline.run(doc.source, pipeline) do
        {:ok, %{result: data}, _} ->
          if should_send?(data) do
            [List.wrap(data)]
          else
            []
          end

        {:error, error} ->
          raise Ash.Error.to_error_class(error)
      end

    result =
      case List.wrap(Process.get(:batch_resolved)) do
        [] ->
          first_results

        batch ->
          batch =
            Enum.map(batch, fn item ->
              pipeline =
                Absinthe.Subscription.Local.pipeline(doc, {:pre_resolved, item})

              {:ok, %{result: data}, _} = Absinthe.Pipeline.run(doc.source, pipeline)

              data
            end)

          [batch] ++ first_results
      end

    Logger.debug("""
    Absinthe Subscription Publication
    Field Topic: #{inspect(key_strategy)}
    Subscription id: #{inspect(topic)}
    Notification Count: #{Enum.count(notifications)}
    """)

    for batch <- result, record <- batch, not is_nil(record) do
      :ok = pubsub.publish_subscription(topic, record)
    end
  rescue
    e ->
      BatchResolver.pipeline_error(e, __STACKTRACE__)
  after
    Process.delete(:batch_resolved)
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
         |> Enum.any?(fn error ->
           Map.get(error, :code) in ["forbidden", "not_found", nil]
         end))
  end

  defp should_send?(_), do: true
end
