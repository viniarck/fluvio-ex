use async_std::future;
use async_std::task;
use flate2::bufread::GzEncoder;
use flate2::Compression;
use fluvio::dataplane::record::ConsumerRecord;
use fluvio::dataplane::ErrorCode;
use fluvio::{ConsumerConfig, Offset, PartitionConsumer};
use fluvio_spu_schema::server::stream_fetch::{
    SmartModuleContextData, SmartModuleInvocation, SmartModuleInvocationWasm, SmartModuleKind,
};
use fluvio_types::defaults::FLUVIO_CLIENT_MAX_FETCH_BYTES;
use futures_util::stream::BoxStream;
use futures_util::StreamExt;
use rustler::{Atom, Encoder, Env, Error, NifResult, NifTuple, ResourceArc, Term};
use std::collections::BTreeMap;
use std::io::Read;
use std::path::Path;
use std::sync::Mutex;
use std::time::Duration;

use crate::atom;
use crate::client;

pub struct ConsumerResource {
    pub consumer: Mutex<PartitionConsumer>,
    pub stream: Mutex<BoxStream<'static, Result<ConsumerRecord, ErrorCode>>>,
}

#[derive(NifTuple)]
pub struct ConsumerResourceResponse {
    pub ok: rustler::Atom,
    pub resource: ResourceArc<ConsumerResource>,
}

fn offset_from_atom(offset_type: Atom, offset_value: u32) -> Result<Offset, Error> {
    if offset_type == atom::from_beginning() {
        Ok(Offset::from_beginning(offset_value))
    } else if offset_type == atom::from_end() {
        Ok(Offset::from_end(offset_value))
    } else if offset_type == atom::absolute() {
        match Offset::absolute(i64::from(offset_value)) {
            Ok(offset) => Ok(offset),
            Err(err) => Err(Error::Term(Box::new(err.to_string())))
        }
    } else {
        Err(Error::Term(Box::new(std::format!(
            "Unsupported offset type {:?}",
            offset_type
        ))))
    }
}

fn new_sm_from_path(
    path: &Path,
    ctx: SmartModuleContextData,
    params: BTreeMap<String, String>,
) -> Result<SmartModuleInvocation, Error> {
    let buffer = match std::fs::read(path) {
        Ok(buffer) => buffer,
        Err(err) => return Err(Error::Term(Box::new(err.to_string()))),
    };
    let mut encoder = GzEncoder::new(buffer.as_slice(), Compression::default());
    let mut vec = Vec::with_capacity(buffer.len());
    if let Err(err) = encoder.read_to_end(&mut vec) {
        return Err(Error::Term(Box::new(err.to_string())));
    };
    Ok(SmartModuleInvocation {
        wasm: SmartModuleInvocationWasm::AdHoc(vec),
        kind: SmartModuleKind::Generic(ctx),
        params: params.into(),
    })
}

fn new_sm_ctx_data(atom: Option<Atom>, acc: Option<Vec<u8>>) -> SmartModuleContextData {
    if atom.unwrap_or_else(|| atom::none()) == atom::aggregate() {
        SmartModuleContextData::Aggregate {
            accumulator: acc.unwrap_or_else(|| vec![]),
        }
    } else {
        SmartModuleContextData::None
    }
}

#[rustler::nif]
fn new_consumer(
    fluvio_res: ResourceArc<client::FluvioResource>,
    topic: String,
    partition: i32,
    offset_type: Atom,
    offset_value: u32,
    max_bytes: Option<i32>,
    sm_path: Option<String>,
    sm_ctx_data: Option<Atom>,
    sm_ctx_data_acc: Option<Vec<u8>>,
) -> NifResult<ConsumerResourceResponse> {
    let fluvio = fluvio_res.fluvio.lock().unwrap();
    let smartmodule = match sm_path {
        Some(sm_path) => {
            let path = Path::new(&sm_path);
            let sm_invocation = new_sm_from_path(
                &path,
                new_sm_ctx_data(sm_ctx_data, sm_ctx_data_acc),
                BTreeMap::new(),
            )?;
            Some(sm_invocation)
        }
        _ => None,
    };
    let fetch_config = match ConsumerConfig::builder()
        .max_bytes(max_bytes.unwrap_or_else(|| FLUVIO_CLIENT_MAX_FETCH_BYTES))
        .smartmodule(smartmodule)
        .build()
    {
        Ok(fetch_config) => fetch_config,
        Err(err) => return Err(Error::Term(Box::new(err.to_string()))),
    };
    let consumer = match task::block_on(fluvio.partition_consumer(topic, partition)) {
        Ok(consumer) => consumer,
        Err(err) => return Err(Error::Term(Box::new(err.to_string()))),
    };
    let offset = offset_from_atom(offset_type, offset_value)?;
    let stream = match task::block_on(consumer.stream_with_config(offset, fetch_config)) {
        Ok(stream) => stream,
        Err(err) => return Err(Error::Term(Box::new(err.to_string()))),
    };
    Ok(ConsumerResourceResponse {
        ok: atom::ok(),
        resource: ResourceArc::new(ConsumerResource {
            consumer: Mutex::new(consumer),
            stream: Mutex::new(Box::pin(stream)),
        }),
    })
}

#[rustler::nif(schedule = "DirtyIo")]
fn next<'a>(
    env: Env<'a>,
    resource: ResourceArc<ConsumerResource>,
    secs_timeout_ms: u64,
) -> NifResult<Term<'a>> {
    let mut stream = resource.stream.lock().unwrap();
    let next_val = match task::block_on(future::timeout(
        Duration::from_millis(secs_timeout_ms),
        stream.next(),
    )) {
        Ok(next_val) => next_val,
        Err(_) => return Ok(atom::stop_next().encode(env))
    };
    match next_val {
        Some(Ok(record)) => Ok((
            record.offset(),
            record.partition(),
            record.key(),
            String::from_utf8_lossy(record.value()).to_string(),
            record.timestamp(),
        )
            .encode(env)),
        Some(Err(err)) => Err(Error::Term(Box::new(err.to_string()))),
        None => Err(Error::Term(Box::new("returned nothing"))),
    }
}
