alias Fluvio.Admin

{:ok, pid} = Admin.start_link()
{:ok, _} = Admin.create_topic(pid, "lobby", %{partitions: 1, replication: 1})
