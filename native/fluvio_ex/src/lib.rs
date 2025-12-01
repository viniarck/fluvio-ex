use rustler::{Env, Term};

pub mod admin;
pub mod atom;
pub mod client;
pub mod consumer;
pub mod producer;

rustler::init!("Elixir.Fluvio.Native", load = on_load);

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(producer::ProducerResource, env);
    rustler::resource!(consumer::ConsumerResource, env);
    rustler::resource!(client::FluvioResource, env);
    rustler::resource!(admin::FluvioAdminResource, env);
    true
}
