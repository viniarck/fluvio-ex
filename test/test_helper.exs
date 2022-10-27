ExUnit.start()

defmodule Fluvio.Native.Mock do
  def admin_connect(), do: {:ok, make_ref()}

  def create_topic(_admin_ref, _topic, _partitions, _replication, _ignore_rack),
    do: :ok

  def delete_topic(_admin_ref, _topic), do: :ok

  def connect(), do: {:ok, make_ref()}
  def platform_version(_fluvio_ref), do: {:ok, "x.y.z"}

  def new_consumer(
        _fluvio_ref,
        _topic,
        _partition,
        _offset_from,
        _offset_value,
        _max_bytes,
        _sm_path,
        _sm_ctx_data,
        _sm_ctx_data_acc
      ),
      do: {:ok, make_ref()}

  def new_producer(
        _fluvio_ref,
        _topic,
        _linger_ms,
        _batch_size_bytes,
        _compression,
        _timeout_ms
      ),
      do: {:ok, make_ref()}

  def send(_producer_ref, _key, _value), do: :ok
  def flush(_producer_ref), do: :ok
  def next(_consumer_ref, _secs_timeout), do: {0, 0, "some_key", "some_value", 0}
end

defmodule Fluvio.Native.ErrMock do
  def admin_connect(), do: {:ok, make_ref()}

  def create_topic(_admin_ref, _topic, _partitions, _replication, _ignore_rack),
    do: {:error, "some_error"}

  def delete_topic(_admin_ref, _topic), do: {:error, "some_error"}

  def connect(), do: {:ok, make_ref()}

  def new_consumer(
        _fluvio_ref,
        _topic,
        _partition,
        _offset_from,
        _offset_value,
        _max_bytes,
        _sm_path,
        _sm_ctx_data,
        _sm_ctx_data_acc
      ),
      do: {:ok, make_ref()}

  def new_producer(
        _fluvio_ref,
        _topic,
        _linger_ms,
        _batch_size_bytes,
        _compression,
        _timeout_ms
      ),
      do: {:ok, make_ref()}

  def send(_producer_ref, _key, _value), do: {:error, "some error"}
  def flush(_producer_ref), do: {:error, "some error"}
  def next(_consumer_ref, _secs_timeout), do: :stop_next
end

defmodule Fluvio.Native.ErrMockNext do
  def connect(), do: {:ok, make_ref()}

  def new_consumer(
        _fluvio_ref,
        _topic,
        _partition,
        _offset_from,
        _offset_value,
        _max_bytes,
        _sm_path,
        _sm_ctx_data,
        _sm_ctx_data_acc
      ),
      do: {:ok, make_ref()}

  def next(_consumer_ref, _secs_timeout), do: {:error, "some error"}
end
