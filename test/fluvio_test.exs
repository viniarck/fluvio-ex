defmodule FluvioTest do
  use ExUnit.Case, async: true
  doctest Fluvio

  test "start_lik" do
    {:ok, fluvio_pid} = Fluvio.start_link([], Fluvio.Native.Mock)
    assert is_pid(fluvio_pid)
    {:ok, "x.y.z"} = Fluvio.platform_version(fluvio_pid)
  end
end
