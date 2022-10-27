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
