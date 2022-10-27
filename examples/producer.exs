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
