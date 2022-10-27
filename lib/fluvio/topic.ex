defmodule Fluvio.Topic do
  @moduledoc false

  defmodule Options do
    @moduledoc false
    defstruct partitions: 1, replication: 1, ignore_rack: false
  end
end
