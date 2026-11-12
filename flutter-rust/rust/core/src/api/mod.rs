//! Everything `pub` under this module is exposed to Dart.
//! After any change here: `flutter_rust_bridge_codegen generate`.

pub mod feedback;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Routes Rust panics and logs to the Dart console.
    flutter_rust_bridge::setup_default_user_utils();
}
