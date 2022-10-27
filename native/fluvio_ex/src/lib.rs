use rustler::{Env, Term};

pub mod atom;
pub mod admin;
pub mod client;
pub mod consumer;
pub mod producer;

rustler::init!(
    "Elixir.Fluvio.Native",
    [
        admin::admin_connect,
        admin::create_topic,
        admin::delete_topic,
        client::connect,
        client::platform_version,
        consumer::new_consumer,
        consumer::next,
        producer::new_producer,
        producer::send,
        producer::flush,
    ],
    load = on_load
);

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(producer::ProducerResource, env);
    rustler::resource!(consumer::ConsumerResource, env);
    rustler::resource!(client::FluvioResource, env);
    rustler::resource!(admin::FluvioAdminResource, env);
    true
}
