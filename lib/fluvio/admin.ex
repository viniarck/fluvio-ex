defmodule Fluvio.Admin do
  @moduledoc """
  Fluvio Admin cluster functionalities. This module is backed by a GenServer.
  """

  use GenServer

  alias Fluvio.Topic.Options

  defmodule GenState do
    @moduledoc false
    defstruct native_mod: nil, fluvio_ref: nil
  end

  @impl true
  def init(%GenState{} = gen_state) do
    {:ok, gen_state}
  end

  @doc """
  Starts a GenServer process linked to the current process connected to Fluvio cluster.
  """
  @spec start_link(list(), any()) :: GenServer.on_start()
  def start_link(gen_opts \\ [], native_mod \\ Fluvio.Native) do
    case native_mod.admin_connect() do
      {:error, msg} ->
        {:error, msg}

      {:ok, fluvio_ref} ->
        GenServer.start_link(
          __MODULE__,
          %GenState{native_mod: native_mod, fluvio_ref: fluvio_ref},
          gen_opts
        )
    end
  end

  @impl true
  def handle_call({:delete_topic, name}, _from, state) do
    response =
      case state.native_mod.delete_topic(state.fluvio_ref, name) do
        {:error, msg} -> {:error, msg}
        :ok -> {:ok, self()}
      end

    {:reply, response, state}
  end

  @impl true
  def handle_call({:create_topic, name, options}, _from, state) do
    response =
      case state.native_mod.create_topic(
             state.fluvio_ref,
             name,
             options.partitions,
             options.replication,
             options.ignore_rack
           ) do
        {:error, msg} -> {:error, msg}
        :ok -> {:ok, self()}
      end

    {:reply, response, state}
  end

  @doc """
  Creates a topic.
  """
  @spec create_topic(pid(), bitstring(), map()) :: {atom(), any()}
  def create_topic(pid, name, options \\ %{partitions: 1, replication: 1, ignore_rack: false}) do
    GenServer.call(pid, {:create_topic, name, struct!(Options, options)})
  end

  @doc """
  Deletes a topic.
  """
  @spec delete_topic(pid(), bitstring()) :: {atom(), any()}
  def delete_topic(pid, name) do
    GenServer.call(pid, {:delete_topic, name})
  end
end
