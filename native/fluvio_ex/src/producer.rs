use async_std::task;
use fluvio::{TopicProducerConfigBuilder, TopicProducerPool};
use fluvio_compression::Compression;
use rustler::{Atom, Error, NifResult, NifTuple, ResourceArc};
use std::sync::Mutex;
use std::time::Duration;

use crate::atom;
use crate::client::FluvioResource;

pub struct ProducerResource {
    pub producer: Mutex<TopicProducerPool>,
}

#[derive(NifTuple)]
pub struct ProducerResourceResponse {
    pub ok: rustler::Atom,
    pub producer: ResourceArc<ProducerResource>,
}

fn compression_from_atom(value: Atom) -> NifResult<Compression> {
    if value == atom::none() {
        Ok(Compression::None)
    } else if value == atom::gzip() {
        Ok(Compression::Gzip)
    } else if value == atom::snappy() {
        Ok(Compression::Snappy)
    } else if value == atom::lz4() {
        Ok(Compression::Lz4)
    } else {
        Err(Error::Term(Box::new(std::format!(
            "Unsupported compression type {:?}",
            value
        ))))
    }
}

#[rustler::nif]
fn new_producer(
    fluvio_res: ResourceArc<FluvioResource>,
    topic: String,
    linger_ms: Option<u64>,
    batch_size_bytes: Option<usize>,
    compression: Option<Atom>,
    timeout_ms: Option<u64>,
) -> NifResult<ProducerResourceResponse> {
    let fluvio = fluvio_res.fluvio.lock().unwrap();
    let config = match TopicProducerConfigBuilder::default()
        .linger(Duration::from_millis(linger_ms.unwrap_or_else(|| 100)))
        .batch_size(batch_size_bytes.unwrap_or_else(|| 16_384))
        .timeout(Duration::from_millis(timeout_ms.unwrap_or_else(|| 1500)))
        .compression(compression_from_atom(
            compression.unwrap_or_else(|| atom::none()),
        )?)
        .build()
    {
        Ok(config) => config,
        Err(err) => return Err(Error::Term(Box::new(err.to_string()))),
    };
    match task::block_on(fluvio.topic_producer_with_config(topic, config)) {
        Ok(producer) => Ok(ProducerResourceResponse {
            ok: atom::ok(),
            producer: ResourceArc::new(ProducerResource {
                producer: Mutex::new(producer),
            }),
        }),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn send(resource: ResourceArc<ProducerResource>, key: String, value: String) -> NifResult<Atom> {
    let producer = resource.producer.lock().unwrap();
    match task::block_on(producer.send(key, value)) {
        Ok(_) => Ok(atom::ok()),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn flush(resource: ResourceArc<ProducerResource>) -> NifResult<Atom> {
    let producer = resource.producer.lock().unwrap();
    match task::block_on(producer.flush()) {
        Ok(_) => Ok(atom::ok()),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}
