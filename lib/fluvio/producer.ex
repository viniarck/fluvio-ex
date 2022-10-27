defmodule Fluvio.Producer do
  @moduledoc """
  TopicProducer functionalities. This module is backed by a GenServer.
  """

  use GenServer
  alias Fluvio

  defmodule Config do
    @moduledoc false
    @enforce_keys [:topic]
    defstruct topic: nil,
              linger_ms: nil,
              batch_size_bytes: nil,
              compression: :none,
              timeout_ms: nil

    @typedoc """
    Fluvio.Producer.Config
    """
    @type t() :: %__MODULE__{
            topic: bitstring(),
            linger_ms: integer(),
            batch_size_bytes: integer(),
            compression: :none | :gzip | :snappy | :lz4,
            timeout_ms: integer()
          }
  end

  defmodule GenState do
    @moduledoc false
    defstruct native_mod: nil, fluvio_ref: nil, producer_ref: nil, config: nil
  end

  @impl true
  def init(%GenState{} = gen_state) do
    {:ok, gen_state}
  end

  defp new_producer(native_mod, fluvio_ref, %Config{} = config) when is_reference(fluvio_ref) do
    native_mod.new_producer(
      fluvio_ref,
      config.topic,
      config.linger_ms,
      config.batch_size_bytes,
      config.compression,
      config.timeout_ms
    )
  end

  @doc """
  Starts a Fluvio TopicProducer GenServer process linked to the current process.

  Config example: %{topic: "some_topic", options: %{}}
  """
  @spec start_link(%{topic: bitstring()}, list(), any()) :: GenServer.on_start()
  def start_link(config, gen_opts \\ [], native_mod \\ Fluvio.Native) do
    config = struct!(Config, config)

    with {:ok, fluvio_ref} <- native_mod.connect(),
         {:ok, producer_ref} <- new_producer(native_mod, fluvio_ref, config) do
      GenServer.start_link(
        __MODULE__,
        %GenState{
          native_mod: native_mod,
          fluvio_ref: fluvio_ref,
          producer_ref: producer_ref,
          config: config
        },
        gen_opts
      )
    end
  end

  @spec send(pid(), bitstring()) :: {atom(), pid()}
  def send(pid, value) when is_pid(pid) and is_bitstring(value) do
    GenServer.call(pid, {:send, "", value})
  end

  @doc """
  Sends a list of string values or tuple key values to this producer's topic. `flush/1` 
  should be called to flush the records in the producer batches.
  """
  @spec send(pid(), list()) :: list()
  def send(pid, values) do
    values
    |> Stream.map(fn value ->
      if is_tuple(value) do
        __MODULE__.send(pid, elem(value, 0), elem(value, 1))
      else
        __MODULE__.send(pid, value)
      end
    end)
    |> Enum.to_list()
  end

  @doc """
  Sends a key value record to this producer's topic. `flush/1` should be 
  be called to flush the records in the producer batches.
  """
  @spec send(pid(), bitstring(), bitstring()) :: {atom(), pid()}
  def send(pid, key, value) do
    GenServer.call(pid, {:send, key, value})
  end

  @doc """
  Flushes all the queued records in the producer batches.
  """
  @spec flush(pid()) :: {atom(), pid()}
  def flush(pid) when is_pid(pid) do
    GenServer.call(pid, :flush)
  end

  @impl true
  def handle_call({:send, key, value}, _from, state) do
    case state.native_mod.send(state.producer_ref, key, value) do
      {:error, error} -> {:reply, {:error, error}, state}
      :ok -> {:reply, {:ok, self()}, state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    case state.native_mod.flush(state.producer_ref) do
      {:error, error} -> {:reply, {:error, error}, state}
      :ok -> {:reply, {:ok, self()}, state}
    end
  end
end
