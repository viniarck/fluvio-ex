alias Fluvio.Producer
alias Fluvio.Consumer
alias Fluvio.Record

defmodule App do
  def start(topic_1 \\ "ping", topic_2 \\ "pong", initial_value \\ "1") do
    children = [{Task.Supervisor, name: TaskSup}]
    {:ok, sup_pid} = Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, pid_one} =
      Task.Supervisor.start_child(
        TaskSup,
        fn ->
          {:ok, p1_pid} = Producer.start_link(%{topic: topic_1})
          {:ok, c2_pid} = Consumer.start_link(%{topic: topic_2, offset: [from_end: 0]})
          IO.inspect("Bootstrapping '#{topic_1}' by sending '#{initial_value}'")
          {:ok, _} = Producer.send(p1_pid, initial_value)
          {:ok, _} = Producer.flush(p1_pid)
          App.PingPong.keep_consuming(c2_pid, p1_pid)
        end,
        restart: :permanent
      )

    {:ok, pid_two} =
      Task.Supervisor.start_child(
        TaskSup,
        fn ->
          {:ok, p2_pid} = Producer.start_link(%{topic: topic_2})
          {:ok, c1_pid} = Consumer.start_link(%{topic: topic_1, offset: [from_end: 0]})
          App.PingPong.keep_consuming(c1_pid, p2_pid)
        end,
        restart: :permanent
      )

    {sup_pid, pid_one, pid_two}
  end

  defmodule PingPong do
    defp produce(p_pid, value) do
      IO.inspect("Producing value: '#{value}'")
      {:ok, _} = Producer.send(p_pid, value)
      {:ok, _} = Producer.flush(p_pid)
    end

    defp do_consume({:ok, %Record{value: "4"}}, _c_pid, _p_pid) do
      raise("simulating an unrecoverable error")
    end

    defp do_consume({:ok, record}, _c_pid, p_pid) do
      IO.inspect("Consumed value: '#{record.value}'")
      produce(p_pid, to_string(String.to_integer(record.value) + 1))
    end

    defp do_consume({:error, _msg}, c_pid, _p_pid), do: Process.exit(c_pid, :kill)
    defp do_consume({:stop_next, _}, _c_pid, _p_pid), do: nil

    def keep_consuming(c_pid, p_pid, min_freq_ms \\ 1000) do
      Consumer.stream_each(c_pid, fn result ->
        Process.sleep(min_freq_ms)
        do_consume(result, c_pid, p_pid)
      end)
    end
  end
end
