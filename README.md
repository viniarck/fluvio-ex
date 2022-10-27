<div align="center">
  <h1><code>fluvio-ex</code></h1>

  <strong>💧Elixir client for <a href="https://www.fluvio.io/">Fluvio</a> streaming platform</strong>

  <p></p>
  <p>
    <a href="https://github.com/viniarck/fluvio-ex/actions/workflows/unit_tests.yml"><img src="https://github.com/viniarck/fluvio-ex/actions/workflows/unit_tests.yml/badge.svg" alt="unit tests status" /></a>
    <a href="https://coveralls.io/r/viniarck/excoveralls?branch=master"><img src="https://coveralls.io/repos/viniarck/fluvio-ex/badge.svg?branch=master" alt="test coverage" /></a>
    <a href="https://hex.pm/packages/fluvio"><img src="https://img.shields.io/hexpm/v/fluvio.svg" alt="hex.pm version" /></a>
    <a href="https://hex.pm/packages/fluvio"><img src="https://img.shields.io/hexpm/dt/fluvio.svg" alt="hex.pm downloads" /></a>
  </p>


  <h3>
    <a href="https://hexdocs.pm/fluvio/Fluvio.html">Docs</a>
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

The following Fluvio Rust abstractions are supported on Elixir:

| **Rust**                    | **Elixir**      |
|-----------------------------|-----------------|
| `fluvio::PartitionConsumer` | Fluvio.Consumer |
| `fluvio::TopicProducer`     | Fluvio.Producer |
| `fluvio::FluvioAdmin`       | Fluvio.Admin    |

Each Elixir abstraction tend to provide equivalent functionalities that [`fluvio` crate exposes](https://docs.rs/fluvio/latest/fluvio/), although more Elixir-oriented to be well integrated with Elixir ecosystem and OTP. `fluvio::FluvioAdmin` is minimally supported since provisioning cluster resources is typically done upfront and not at the application level, but for experimentation it's useful to have `Fluvio.Admin`.

## Examples

### Consumer

This snippet illustrates a `Consumer` connected to a `"lobby"` topic and using an optional SmarModule filter. Initially, this consumer calls `Consumer.stream_unfold/2` to lazily take 4 reords and chunk every 2 records, printing them. After that, it keeps executing the `Consumer.stream_each/2` that will keep consuming from the stream. `Consumer.stream_each` is a higher-level function that recursively calls `Consumer.stream_next/2`.

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

### Producer

This snippet illustrates a `Producer` connected to a `"lobby"` topic. Initially, a string "hello" is sent and flushed, after that, more three strigs `"are"`, `"you"`, `"there?"` are sent and asserted. Finally, string numbers from 1 to 20 are sent asynchronously in chunk of 10 with a flush between each iteration. If you're going to try to send and await records asynchronusly make sure that it's OK for your application and also benchmark to confirm if the overhead and async approach being used is beneficial, `Fluvio.Producer` also has options like `linger_ms`, batch_size_bytes` and `compression` can influence the throughput outcome:


```elixir
alias Fluvio.Producer

{:ok, pid} = Producer.start_link(%{topic: "lobby"})

{:ok, _} = Producer.send(pid, "hello")
{:ok, _} = Producer.flush(pid)

Producer.send(pid, ["are", "you", "there?"])
|> Enum.each(&({:ok, _} = &1))

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
