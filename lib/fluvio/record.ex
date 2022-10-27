defmodule Fluvio.Record do
  @moduledoc false
  defstruct offset: 0, partition: 0, key: nil, value: nil, timestamp: nil

  @typedoc """
  Fluvio.Record
  """
  @type t() :: %__MODULE__{
          offset: integer(),
          partition: integer(),
          key: bitstring(),
          value: bitstring(),
          timestamp: integer()
        }
end
