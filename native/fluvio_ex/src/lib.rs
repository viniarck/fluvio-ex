use rustler::{Env, Term};

pub mod admin;
pub mod atom;
pub mod client;
pub mod consumer;
pub mod producer;

use admin::FluvioAdminResource;
use client::FluvioResource;
use consumer::ConsumerResource;
use producer::ProducerResource;

rustler::init!("Elixir.Fluvio.Native", load = on_load);

fn on_load(env: Env, _info: Term) -> bool {
    env.register::<ProducerResource>().is_ok()
        && env.register::<ConsumerResource>().is_ok()
        && env.register::<FluvioResource>().is_ok()
        && env.register::<FluvioAdminResource>().is_ok()
}
