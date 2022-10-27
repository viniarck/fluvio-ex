rustler::atoms! {
    ok,
    error,

    // Future
    stop_next,

    // Offset
    from_beginning,
    from_end,
    absolute,

    // Compression (including none)
    gzip,
    snappy,
    lz4,

    // SmartModuleContextData
    none,
    aggregate,
}
