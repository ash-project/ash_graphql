defmodule AshGraphql.Dataloader do
  @moduledoc "The dataloader in charge of resolving "
  defstruct [
    :api,
    batches: %{},
    results: %{},
    default_params: %{}
  ]

  @type t :: %__MODULE__{
          api: Ash.Api.t(),
          batches: map,
          results: map,
          default_params: map
        }

  @type api_opts :: Keyword.t()
  @type batch_fun :: (Ash.Resource.t(), Ash.Query.t(), any, [any], api_opts -> [any])

  @doc """
  Create an Ash Dataloader source.
  This module handles retrieving data from Ash for dataloader. It requires a
  valid Ash API.
  """
  @spec new(Ash.Api.t()) :: t
  def new(api) do
    %__MODULE__{api: api}
  end

  defimpl Dataloader.Source do
    def run(source) do
      results = Dataloader.async_safely(__MODULE__, :run_batches, [source])

      results =
        Map.merge(source.results, results, fn _, {:ok, v1}, {:ok, v2} ->
          {:ok, Map.merge(v1, v2)}
        end)

      %{source | results: results, batches: %{}}
    end

    def fetch(source, batch_key, item) do
      {batch_key, item_key, _item} =
        batch_key
        |> normalize_key(source.default_params)
        |> get_keys(item)

      case Map.fetch(source.results, batch_key) do
        {:ok, batch} ->
          fetch_item_from_batch(batch, item_key)

        :error ->
          {:error, "Unable to find batch #{inspect(batch_key)}"}
      end
    end

    defp fetch_item_from_batch({:error, _reason} = tried_and_failed, _item_key),
      do: tried_and_failed

    defp fetch_item_from_batch({:ok, batch}, item_key) do
      case Map.fetch(batch, item_key) do
        :error -> {:error, "Unable to find item #{inspect(item_key)} in batch"}
        result -> result
      end
    end

    def put(source, _batch, _item, %Ash.NotLoaded{type: :relationship}) do
      source
    end

    def put(source, batch, item, result) do
      batch = normalize_key(batch, source.default_params)
      {batch_key, item_key, _item} = get_keys(batch, item)

      results =
        Map.update(
          source.results,
          batch_key,
          {:ok, %{item_key => result}},
          fn {:ok, map} -> {:ok, Map.put(map, item_key, result)} end
        )

      %{source | results: results}
    end

    def load(source, batch, item) do
      {batch_key, item_key, item} =
        batch
        |> normalize_key(source.default_params)
        |> get_keys(item)

      if fetched?(source.results, batch_key, item_key) do
        source
      else
        entry = {item_key, item}

        update_in(source.batches, fn batches ->
          Map.update(batches, batch_key, MapSet.new([entry]), &MapSet.put(&1, entry))
        end)
      end
    end

    defp fetched?(results, batch_key, item_key) do
      case results do
        %{^batch_key => {:ok, %{^item_key => _}}} -> true
        _ -> false
      end
    end

    def pending_batches?(%{batches: batches}) do
      batches != %{}
    end

    def timeout(_) do
      Dataloader.default_timeout()
    end

    defp related(path, resource) do
      Ash.Resource.Info.related(resource, path) ||
        raise """
        Valid relationship for path #{inspect(path)} not found on resource #{inspect(resource)}
        """
    end

    defp get_keys({assoc_field, opts}, %resource{} = record) when is_atom(assoc_field) do
      validate_resource(resource)
      pkey = Ash.Resource.Info.primary_key(resource)
      id = Enum.map(pkey, &Map.get(record, &1))

      queryable = related([assoc_field], resource)

      {{:assoc, resource, self(), assoc_field, queryable, opts}, id, record}
    end

    defp get_keys(key, item) do
      raise """
      Invalid: #{inspect(key)}
      #{inspect(item)}
      The batch key must either be a schema module, or an association name.
      """
    end

    defp validate_resource(resource) do
      unless Ash.Resource.Info.resource?(resource) do
        raise "The given module - #{resource} - is not an Ash resouce."
      end
    end

    defp normalize_key({key, params}, default_params) do
      {key, Enum.into(params, default_params)}
    end

    defp normalize_key(key, default_params) do
      {key, default_params}
    end

    def run_batches(source) do
      options = [
        timeout: Dataloader.default_timeout(),
        on_timeout: :kill_task
      ]

      results =
        source.batches
        |> Task.async_stream(
          fn batch ->
            id = :erlang.unique_integer()
            system_time = System.system_time()
            start_time_mono = System.monotonic_time()

            emit_start_event(id, system_time, batch)
            batch_result = run_batch(batch, source)
            emit_stop_event(id, start_time_mono, batch)

            batch_result
          end,
          options
        )
        |> Enum.map(fn
          {:ok, {_key, result}} -> {:ok, result}
          {:exit, reason} -> {:error, reason}
        end)

      source.batches
      |> Enum.map(fn {key, _set} -> key end)
      |> Enum.zip(results)
      |> Map.new()
    end

    defp run_batch(
           {{:assoc, source_resource, _pid, field, _resource, opts} = key, records},
           source
         ) do
      {ids, records} = Enum.unzip(records)
      query = opts[:query]
      api_opts = opts[:api_opts]
      tenant = opts[:tenant] || tenant_from_records(records)
      empty = source_resource |> struct |> Map.fetch!(field)
      records = records |> Enum.map(&Map.put(&1, field, empty))

      cardinality = Ash.Resource.Info.relationship(source_resource, field).cardinality

      query =
        query
        |> Ash.Query.new()
        |> Ash.Query.set_tenant(tenant)

      loaded = source.api.load!(records, [{field, query}], api_opts || [])

      results =
        case cardinality do
          :many ->
            Enum.map(loaded, fn record ->
              List.wrap(Map.get(record, field))
            end)

          :one ->
            Enum.map(loaded, fn record ->
              Map.get(record, field)
            end)
        end

      {key, Map.new(Enum.zip(ids, results))}
    end

    defp tenant_from_records([%{__metadata__: %{tenant: tenant}}]) when not is_nil(tenant) do
      tenant
    end

    defp tenant_from_records(_), do: nil

    defp emit_start_event(id, system_time, batch) do
      :telemetry.execute(
        [:dataloader, :source, :batch, :run, :start],
        %{system_time: system_time},
        %{id: id, batch: batch}
      )
    end

    defp emit_stop_event(id, start_time_mono, batch) do
      :telemetry.execute(
        [:dataloader, :source, :batch, :run, :stop],
        %{duration: System.monotonic_time() - start_time_mono},
        %{id: id, batch: batch}
      )
    end
  end
end
