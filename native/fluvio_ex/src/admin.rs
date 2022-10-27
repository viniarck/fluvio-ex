use async_std::task;
use fluvio::metadata::topic::TopicSpec;
use fluvio::FluvioAdmin;
use rustler::{Atom, Error, NifResult, NifTuple, ResourceArc};
use std::sync::Mutex;

use crate::atom;

pub struct FluvioAdminResource {
    pub admin: Mutex<FluvioAdmin>,
}

#[derive(NifTuple)]
pub struct FluvioAdminResourceResponse {
    pub ok: rustler::Atom,
    pub resource: ResourceArc<FluvioAdminResource>,
}

#[rustler::nif]
fn delete_topic(admin_res: ResourceArc<FluvioAdminResource>, topic: String) -> NifResult<Atom> {
    let admin = admin_res.admin.lock().unwrap();
    match task::block_on(admin.delete::<TopicSpec, String>(topic.clone())) {
        Ok(_) => Ok(atom::ok()),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}

#[rustler::nif]
fn create_topic(
    admin_res: ResourceArc<FluvioAdminResource>,
    topic: String,
    partitions: i32,
    replication: i32,
    ignore_rack: Option<bool>,
) -> NifResult<Atom> {
    let admin = admin_res.admin.lock().unwrap();
    let topic_spec = TopicSpec::new_computed(partitions, replication, ignore_rack);
    match task::block_on(admin.create(topic.clone(), false, topic_spec)) {
        Ok(_) => Ok(atom::ok()),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}

#[rustler::nif]
fn admin_connect() -> NifResult<FluvioAdminResourceResponse> {
    match task::block_on(FluvioAdmin::connect()) {
        Ok(fluvio) => Ok(FluvioAdminResourceResponse {
            ok: atom::ok(),
            resource: ResourceArc::new(FluvioAdminResource {
                admin: Mutex::new(fluvio),
            }),
        }),
        Err(err) => Err(Error::Term(Box::new(err.to_string()))),
    }
}
