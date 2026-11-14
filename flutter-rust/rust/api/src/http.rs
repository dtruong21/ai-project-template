//! Response helpers. Every non-2xx body goes through [`error`], so clients
//! can rely on one shape: `{"error": {"code": ..., "message": ...}}`.

use serde::de::DeserializeOwned;
use shared::{codes, ApiErrorBody};
use worker::{console_error, Request, Response, Result};

pub fn error(status: u16, code: &str, message: impl Into<String>) -> Result<Response> {
    Ok(Response::from_json(&ApiErrorBody::new(code, message))?.with_status(status))
}

pub fn unauthenticated(reason: String) -> Result<Response> {
    error(401, codes::UNAUTHENTICATED, reason)
}

pub fn not_found() -> Result<Response> {
    error(404, codes::NOT_FOUND, "Not found.")
}

/// For failures the caller cannot fix. The real cause goes to the Worker
/// log (`wrangler tail`); the client only learns that it failed.
pub fn internal(cause: &worker::Error) -> Result<Response> {
    console_error!("internal error: {cause}");
    error(500, codes::INTERNAL, "Something went wrong. Try again.")
}

pub fn json<T: serde::Serialize>(status: u16, value: &T) -> Result<Response> {
    Ok(Response::from_json(value)?.with_status(status))
}

pub fn no_content() -> Result<Response> {
    Ok(Response::empty()?.with_status(204))
}

/// Parses a JSON body into a `shared` model.
///
/// Uses serde_json, NOT `req.json()`: the latter goes through
/// serde-wasm-bindgen, which silently ignores `deny_unknown_fields` — a body
/// with a smuggled `uid` would be accepted.
pub async fn parse_body<T: DeserializeOwned>(req: &mut Request) -> Option<T> {
    serde_json::from_str(&req.text().await.ok()?).ok()
}

pub fn invalid_body() -> Result<Response> {
    error(400, codes::INVALID_BODY, "Invalid request body.")
}
