defmodule Fluvio.Native do
  @moduledoc false
  use Rustler, otp_app: :fluvio, crate: "fluvio_ex"

  def admin_connect(), do: :erlang.nif_error(:nif_not_loaded)

  def create_topic(_admin_ref, _topic, _partitions, _replication, _ignore_rack),
    do: :erlang.nif_error(:nif_not_loaded)

  def delete_topic(_admin_ref, _topic), do: :erlang.nif_error(:nif_not_loaded)

  def connect(), do: :erlang.nif_error(:nif_not_loaded)
  def platform_version(_fluvio_ref), do: :erlang.nif_error(:nif_not_loaded)

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
      do: :erlang.nif_error(:nif_not_loaded)

  def new_producer(
        _fluvio_ref,
        _topic,
        _linger_ms,
        _batch_size_bytes,
        _compression,
        _timeout_ms
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def send(_producer_ref, _key, _value), do: :erlang.nif_error(:nif_not_loaded)
  def flush(_producer_ref), do: :erlang.nif_error(:nif_not_loaded)
  def next(_consumer_ref, __timeout_ms), do: :erlang.nif_error(:nif_not_loaded)
end
