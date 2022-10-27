alias Fluvio.Consumer

{:ok, pid} = Consumer.start_link(%{topic: "lobby", offset: [from_beginning: 0]})

Consumer.stream_each(pid, fn result ->
  case result do
    {:ok, record} -> IO.inspect(record)
    {:error, msg} -> IO.inspect("Error: #{msg}")
  end
end)
