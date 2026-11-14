//! Cloudflare Worker — the only thing that talks to D1.
//!
//! Every route follows the same four steps, in this order:
//!   1. authenticate  (`auth::uid_from_request` — Firebase ID token)
//!   2. parse         (`http::parse_body` into a typed `shared` model)
//!   3. validate      (the same `shared` rule the app already ran)
//!   4. query         (bound parameters, scoped `WHERE uid = ?`)
//!
//! This replaces Firestore security rules: there is no direct client-to-DB
//! path, so a route that skips step 1 is a public endpoint.
//!
//! Errors: every non-2xx response is `{"error": {"code", "message"}}`
//! (`http::error`). Codes are listed in `shared::codes`.

use worker::*;

mod account;
mod auth;
mod feedback;
mod http;
mod profile;

#[event(fetch)]
async fn fetch(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let result = Router::new()
        // The only unauthenticated route.
        .get("/health", |_, _| Response::ok("ok"))
        .post_async("/v1/feedback", feedback::create)
        .get_async("/v1/feedback", feedback::list)
        .delete_async("/v1/feedback/:id", feedback::delete)
        .get_async("/v1/profile", profile::get)
        .put_async("/v1/profile", profile::put)
        .delete_async("/v1/account", account::delete)
        .or_else_any_method("/*path", |_, _| http::not_found())
        .run(req, env)
        .await;

    // Nothing unexpected (D1 down, a bug) reaches the client as raw text.
    match result {
        Ok(response) => Ok(response),
        Err(cause) => http::internal(&cause),
    }
}
