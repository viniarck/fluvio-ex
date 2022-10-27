defmodule FluvioAdminTest do
  use ExUnit.Case, async: true
  doctest Fluvio.Admin

  alias Fluvio.Admin

  test "start_link" do
    {:ok, pid} = Admin.start_link([], Fluvio.Native.Mock)
    assert is_pid(pid)
  end

  test "create_topic" do
    {:ok, pid} = Admin.start_link([], Fluvio.Native.Mock)
    {:ok, _} = Admin.create_topic(pid, "some_topic")
  end

  test "delete_topic" do
    {:ok, pid} = Admin.start_link([], Fluvio.Native.Mock)
    {:ok, _} = Admin.delete_topic(pid, "some_topic")
  end

  test "create_topic error case" do
    {:ok, pid} = Admin.start_link([], Fluvio.Native.ErrMock)
    {:error, "some_error"} = Admin.create_topic(pid, "some_topic")
  end

  test "delete_topic error case" do
    {:ok, pid} = Admin.start_link([], Fluvio.Native.ErrMock)
    {:error, "some_error"} = Admin.delete_topic(pid, "some_topic")
  end
end
