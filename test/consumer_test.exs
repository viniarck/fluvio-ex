defmodule ConsumerTest do
  use ExUnit.Case, async: true
  doctest Fluvio.Consumer
  alias Fluvio.Consumer
  alias Fluvio.Record
  alias Fluvio.Native.Mock
  alias Fluvio.Native.ErrMock
  alias Fluvio.Native.ErrMockNext

  test "start_link" do
    {:ok, pid} = Consumer.start_link(%{topic: "some_topic", offset: [from_beginning: 0]}, [], Mock)

    assert is_pid(pid)
  end

  test "consumer stream_next" do
    {:ok, pid} =
      Consumer.start_link(
        %{topic: "some_topic"},
        [],
        Mock
      )

    assert is_pid(pid)

    {:ok, %Record{key: "some_key", value: "some_value", timestamp: 0}} = Consumer.stream_next(pid)
  end

  test "consumer stream_next stop iteration" do
    {:ok, pid} = Consumer.start_link(%{topic: "some_topic"}, [], ErrMock)
    {:stop_next, :stop_next} = Consumer.stream_next(pid)
  end

  test "consumer stream_next error case" do
    {:ok, pid} = Consumer.start_link(%{topic: "some_topic"}, [], ErrMockNext)
    {:error, "some error"} = Consumer.stream_next(pid)
  end

  test "consumer stream_unfold" do
    {:ok, pid} = Consumer.start_link(%{topic: "some_topic"}, [], Mock)

    assert is_pid(pid)

    response =
      Consumer.stream_unfold(pid)
      |> Stream.take(1)
      |> Enum.to_list()
      |> hd

    %Record{key: "some_key", value: "some_value", timestamp: 0} = response
  end

  test "consumer stream_unfold error case should stop unfolding" do
    {:ok, pid} = Consumer.start_link(%{topic: "some_topic"}, [], ErrMockNext)

    assert is_pid(pid)

    [] =
      Consumer.stream_unfold(pid)
      |> Stream.take(1)
      |> Enum.to_list()
  end
end
