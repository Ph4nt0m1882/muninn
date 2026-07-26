#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Initialize env_logger for Rust logging
    let _ = env_logger::builder()
        .filter_level(log::LevelFilter::Debug)
        .try_init();

    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
