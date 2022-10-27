defmodule ProducerTest do
  use ExUnit.Case, async: true
  doctest Fluvio.Consumer
  alias Fluvio.Producer
  alias Fluvio.Native.Mock
  alias Fluvio.Native.ErrMock

  def producer_start_link_pid() do
    {:ok, pid} = Producer.start_link(%{topic: "some_topic"}, [], Mock)
    assert is_pid(pid)
    pid
  end

  test "start_link" do
    {:ok, pid} = Producer.start_link(%{topic: "some_topic"}, [], Mock)
    assert is_pid(pid)
  end

  test "send key value" do
    {:ok, pid} = Producer.send(producer_start_link_pid(), "some_key", "some_value")
    assert is_pid(pid)
  end

  test "send value" do
    {:ok, pid} = Producer.send(producer_start_link_pid(), "some_value")
    assert is_pid(pid)
  end

  test "send values" do
    [{:ok, pid1}, {:ok, pid2}] =
      Producer.send(producer_start_link_pid(), ["1", {"some_key", "some_value"}])

    assert is_pid(pid1)
    assert is_pid(pid2)
  end

  test "send value error case" do
    {:ok, pid} = Producer.start_link(%{topic: "some_topic"}, [], ErrMock)
    {:error, "some error"} = Producer.send(pid, "some_value")
  end

  test "flush" do
    {:ok, pid} = Producer.flush(producer_start_link_pid())
    assert is_pid(pid)
  end

  test "flush error case" do
    {:ok, pid} = Producer.start_link(%{topic: "some_topic"}, [], ErrMock)
    {:error, "some error"} = Producer.flush(pid)
  end
end
