defmodule Fluvio do
  @moduledoc """
  This module provides high-level Fluvio interface for cluster functionalities.
  """
  use GenServer

  defmodule GenState do
    @moduledoc false
    defstruct native_mod: nil, fluvio_ref: nil
  end

  @impl true
  def init(%GenState{} = gen_state) do
    {:ok, gen_state}
  end

  @impl true
  def handle_call(:connect, _from, state) do
    response = state.native_mod.connect()
    {:reply, response, Map.put(state, :fluvio_ref, response |> elem(1))}
  end

  @impl true
  def handle_call(:platform_version, _from, state) do
    {:reply, state.native_mod.platform_version(state.fluvio_ref), state}
  end

  @doc """
  Starts a GenServer process linked to the current process connected to Fluvio cluster.
  """
  @spec start_link(list(), any()) :: GenServer.on_start()
  def start_link(gen_opts \\ [], native_mod \\ Fluvio.Native) do
    case native_mod.connect() do
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

  @doc """
  Gets the platform version of the connected cluster.
  """
  @spec platform_version(pid()) :: {atom(), any()}
  def platform_version(pid) when is_pid(pid) do
    GenServer.call(pid, :platform_version)
  end
end
