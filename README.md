<div align="center">
  <h1><code>fluvio-ex</code></h1>

  <strong>💧Elixir client for <a href="https://www.fluvio.io/">Fluvio</a> streaming platform</strong>

  <p></p>
  <p>
    <a href="https://github.com/viniarck/fluvio-ex/actions/workflows/unit_tests.yml"><img src="https://github.com/viniarck/fluvio-ex/actions/workflows/unit_tests.yml/badge.svg" alt="unit tests status" /></a>
    <a href="https://coveralls.io/r/viniarck/fluvio-ex?branch=master"><img src="https://coveralls.io/repos/viniarck/fluvio-ex/badge.svg?branch=master" alt="test coverage" /></a>
    <a href="https://hex.pm/packages/fluvio"><img src="https://img.shields.io/hexpm/v/fluvio.svg" alt="hex.pm version" /></a>
    <a href="https://hex.pm/packages/fluvio"><img src="https://img.shields.io/hexpm/dt/fluvio.svg" alt="hex.pm downloads" /></a>
  </p>


  <h3>
    <a href="https://hexdocs.pm/fluvio/readme.html">Docs</a>
  </h3>
</div>


## Installation

You can add `fluvio` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fluvio, "~> 0.2.0"}
  ]
end
```
## Features

The following Fluvio Rust interfaces are supported on Elixir:

| **Rust**                    | **Elixir**        |
|-----------------------------|-------------------|
| `fluvio::PartitionConsumer` | `Fluvio.Consumer` |
| `fluvio::TopicProducer`     | `Fluvio.Producer` |
| `fluvio::FluvioAdmin`       | `Fluvio.Admin`    |

Each Elixir module tends to provide equivalent functionalities that [`fluvio` crate](https://docs.rs/fluvio/latest/fluvio/) exposes, although Elixir-oriented to be well integrated with Elixir ecosystem and OTP. 

> `fluvio::FluvioAdmin` is minimally supported since provisioning cluster resources is typically done upfront and not at the application level, but for experimentation it's useful to have `Fluvio.Admin`.

## Examples

### Consumer

[This snippet](./examples/consumer_smartmodule.exs) illustrates a `Fluvio.Consumer` connected to a `"lobby"` topic and using an optional SmartModule filter. Initially, it lazily unfolds the infinite stream, taking 4 records and chunking every 2. Finally, it keeps consuming it.

```elixir
alias Fluvio.Consumer

{:ok, pid} =
  Consumer.start_link(%{
    topic: "lobby",
    offset: [from_beginning: 0],
    smartmodule_path: "./examples/wasm/map_reverse.wasm"
  })

Consumer.stream_unfold(pid)
|> Stream.take(4)
|> Stream.chunk_every(2)
|> Enum.to_list()
|> IO.inspect()

Consumer.stream_each(pid, fn result ->
  case result do
    {:ok, record} -> IO.inspect(record)
    {:error, msg} -> IO.inspect("Error: #{msg}")
  end
end)
```

```console
MIX_ENV=prod mix run examples/consumer_smartmodule.exs
```

### Producer

[This snippet](./examples/producer.exs) illustrates a `Fluvio.Producer` connected to a `"lobby"` topic. Initially, a string value `"hello"` is sent and flushed synchronously. Also, 20 values are sent asynchronously and flushed in chunks of 10.

```elixir
alias Fluvio.Producer

{:ok, pid} = Producer.start_link(%{topic: "lobby"})

{:ok, _} = Producer.send(pid, "hello")
{:ok, _} = Producer.flush(pid)

[] =
  1..20
  |> Stream.chunk_every(10)
  |> Stream.flat_map(fn chunk ->
    [
      chunk
      |> Enum.map(fn value ->
        Task.async(fn -> {Producer.send(pid, to_string(value)), value} end)
      end)
      |> Task.await_many()
      |> Enum.filter(&match?({{:error, _msg}, _value}, &1)),
      [{Producer.flush(pid), :flush}]
      |> Enum.filter(&match?({{:error, _msg}, _value}, &1))
    ]
  end)
  |> Stream.concat()
  |> Enum.to_list()
```

```console
MIX_ENV=prod mix run examples/producer.exs
```

### Supervised Producer and Consumer

[This example](./examples/ping_pong.exs) demonstrates a ping pong application that uses two pairs of a `Fluvio.Producer` and `Fluvio.Consumer`, which have been linked to an Elixir `Supervisor` (`Task.Supervisor`) to provide process fault-tolerance inside your app. You could also strategically restart and init with a different `Fluvio.Consumer` offset.

```elixir
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
```

If you were to run this example, you'd see that once the pairs of producer and consumer start, the initial value `"1"` is sent, and each pair will keep incrementing the value and sending it. Once the value `"4"` is reached, the ping consumer simulates an unrecoverable error, which will crash this process and the supervisor will restart it:

```console
MIX_ENV=prod iex -S mix
iex(1)> c "examples/ping_pong.exs"
[App, App.PingPong]
iex(2)> App.start()
{#PID<0.220.0>, #PID<0.222.0>, #PID<0.223.0>}


"Bootstrapping 'ping' by sending '1'"
"Consumed value: '1'"
"Producing value: '2'"
"Consumed value: '2'"
"Producing value: '3'"
"Consumed value: '3'"
"Producing value: '4'"
iex(3)>
01:31:46.911 [error] Task #PID<0.222.0> started from #PID<0.207.0> terminating
** (RuntimeError) simulating an unrecoverable error
    examples/ping_pong.exs:46: App.PingPong.do_consume/3
    (fluvio 0.2.0) lib/fluvio/consumer.ex:172: Fluvio.Consumer.stream_each/3
    (elixir 1.14.0) lib/task/supervised.ex:89: Task.Supervised.invoke_mfa/2
    (stdlib 4.1) proc_lib.erl:240: :proc_lib.init_p_do_apply/3
Function: #Function<0.131083353/0 in App.start/3>
    Args: []
"Bootstrapping 'ping' by sending '1'"
"Consumed value: '1'"
"Producing value: '2'"
"Consumed value: '2'"
```
