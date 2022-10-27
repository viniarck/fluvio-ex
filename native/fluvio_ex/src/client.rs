use async_std::task;
use fluvio::Fluvio;
use rustler::{Error, NifResult, NifTuple, ResourceArc};
use std::sync::Mutex;

use crate::atom;

pub struct FluvioResource {
    pub fluvio: Mutex<Fluvio>,
}

#[derive(NifTuple)]
pub struct FluvioResourceResponse {
    pub ok: rustler::Atom,
    pub resource: ResourceArc<FluvioResource>,
}

#[rustler::nif]
fn connect() -> NifResult<FluvioResourceResponse> {
    match task::block_on(Fluvio::connect()) {
        Ok(fluvio) => Ok(FluvioResourceResponse {
            ok: atom::ok(),
            resource: ResourceArc::new(FluvioResource {
                fluvio: Mutex::new(fluvio),
            }),
        }),
        Err(err) => Err(Error::Term(Box::new(err.to_string())))
    }
}

#[rustler::nif]
fn platform_version(fluvio_res: ResourceArc<FluvioResource>) -> NifResult<String> {
    let fluvio = fluvio_res.fluvio.lock().unwrap();
    Ok(fluvio.platform_version().to_string())
}
