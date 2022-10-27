defmodule Fluvio.Consumer do
  @moduledoc """
  PartitionConsumer functionalities. This module is backed by a GenServer.
  """

  use GenServer
  alias Fluvio.Record

  defmodule Config do
    @moduledoc """
    Consumer configuration.
    """
    @enforce_keys [:topic]
    defstruct topic: nil,
              partition: 0,
              offset: [from_end: 0],
              max_bytes: nil,
              smartmodule_path: nil,
              smartmodule_context_data: nil,
              smartmodule_context_data_acc: nil

    @typedoc """
    Fluvio.Consumer.Config
    """
    @type t() :: %__MODULE__{
            topic: bitstring(),
            partition: integer(),
            offset: [{:from_beginning | :from_end | :absolute, integer()}],
            max_bytes: integer(),
            smartmodule_path: bitstring(),
            smartmodule_context_data: list(),
            smartmodule_context_data_acc: integer()
          }
  end

  defmodule GenState do
    @moduledoc false
    defstruct native_mod: nil,
              fluvio_ref: nil,
              consumer_ref: nil,
              config: nil
  end

  @impl true
  def init(%GenState{} = gen_state) do
    {:ok, gen_state}
  end

  @impl true
  def handle_call({:stream_unfold, timeout_iter_ms}, _from, state) do
    consumer_pid = self()

    unfold =
      Stream.unfold(nil, fn _value ->
        do_unfold(state.native_mod, state.consumer_ref, timeout_iter_ms, consumer_pid)
      end)

    {:reply, unfold, state}
  end

  @impl true
  def handle_call({:stream_next, timeout_iter_ms}, _from, state) do
    result = do_stream_next(state.native_mod, state.consumer_ref, timeout_iter_ms)
    {:reply, result, state}
  end

  defp new_consumer(
         native_mod,
         fluvio_ref,
         config = %Config{}
       )
       when is_reference(fluvio_ref) do
    native_mod.new_consumer(
      fluvio_ref,
      config.topic,
      config.partition,
      config.offset |> hd |> elem(0),
      config.offset |> hd |> elem(1),
      config.max_bytes,
      if is_bitstring(config.smartmodule_path) do
        Path.expand(config.smartmodule_path)
      else
        nil
      end,
      config.smartmodule_context_data,
      config.smartmodule_context_data_acc
    )
  end

  @doc """
  Starts a Fluvio PartitionConsumer GenServer process linked to the current process.
  """
  @spec start_link(map(), list(), any()) :: GenServer.on_start()
  def start_link(config, gen_opts \\ [], native_mod \\ Fluvio.Native) do
    config = struct!(Config, config)

    with {:ok, fluvio_ref} <- native_mod.connect(),
         {:ok, consumer_ref} <- new_consumer(native_mod, fluvio_ref, config) do
      GenServer.start_link(
        __MODULE__,
        %GenState{
          native_mod: native_mod,
          fluvio_ref: fluvio_ref,
          consumer_ref: consumer_ref,
          config: config
        },
        gen_opts
      )
    end
  end

  defp do_unfold(native_mod, consumer_ref, timeout_iter_ms, consumer_pid) do
    case do_stream_next(native_mod, consumer_ref, timeout_iter_ms) do
      {:stop_next, :stop_next} ->
        do_unfold(native_mod, consumer_ref, timeout_iter_ms, consumer_pid)

      {:ok, record} ->
        {record, record}

      {:error, _msg} ->
        nil
    end
  end

  @doc """
  Unfolds the infinite stream lazily.

  timeout_iter_ms is a low-level iteration timeout in ms to avoid blocking the 
  DirtyIO Rust NIF for too long.
  """
  @spec stream_unfold(pid(), integer()) :: Stream
  def stream_unfold(pid, timeout_iter_ms \\ 2000) when is_pid(pid) do
    GenServer.call(pid, {:stream_unfold, timeout_iter_ms})
  end

  defp do_stream_next(native_mod, consumer_ref, timeout_iter_ms) do
    case native_mod.next(consumer_ref, timeout_iter_ms) do
      {offset, partition, key, value, timestamp} ->
        {:ok,
         %Record{
           offset: offset,
           partition: partition,
           key: key,
           value: value,
           timestamp: timestamp
         }}

      :stop_next ->
        {:stop_next, :stop_next}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets next record of the stream. If you want to traverse continuously the stream, you 
  can call `stream_each/3`, or alternatively recursively call this function.
  """
  @spec stream_next(pid(), integer()) ::
          {:ok, %Record{}} | {:stop_next, :stop_next} | {:error, bitstring()}
  def stream_next(pid, timeout_iter_ms \\ 2000) when is_pid(pid) do
    GenServer.call(pid, {:stream_next, timeout_iter_ms})
  end

  defp loop_fn({:stop_next, :stop_next}, _func), do: nil
  defp loop_fn(result, func), do: func.(result)

  @doc """
  Invokes the given func/1 for each result in the stream continuously.
  """
  @spec stream_each(pid(), fun(), integer()) :: :ok
  def stream_each(pid, func, timeout_iter \\ 2) do
    loop_fn(stream_next(pid, timeout_iter), func)
    stream_each(pid, func)
  end
end
