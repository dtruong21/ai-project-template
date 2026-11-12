//! Cloudflare Worker — the only thing that talks to D1.
//!
//! Every route follows the same four steps, in this order:
//!   1. authenticate  (`auth::uid_from_request` — Firebase ID token)
//!   2. parse         (typed `shared` model, unknown fields rejected)
//!   3. validate      (the same `shared` rule the app already ran)
//!   4. query         (bound parameters only — never format SQL by hand)
//!
//! This replaces Firestore security rules: there is no direct client-to-DB
//! path, so a route that skips step 1 is a public endpoint.

use serde_json::json;
use shared::NewFeedback;
use worker::*;

mod auth;

#[event(fetch)]
async fn fetch(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("ok"))
        .post_async("/v1/feedback", create_feedback)
        .run(req, env)
        .await
}

async fn create_feedback(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return Response::error(reason, 401),
    };

    // Parse with serde_json, NOT `req.json()`: the latter goes through
    // serde-wasm-bindgen, which silently ignores `deny_unknown_fields`.
    let input: NewFeedback = match serde_json::from_str(&req.text().await?) {
        Ok(input) => input,
        Err(_) => return Response::error("Invalid request body.", 400),
    };

    if let Err(e) = input.validate() {
        return Response::error(e.to_string(), 422);
    }

    // `id` and `created_at` are filled by column defaults (see migrations/).
    ctx.env
        .d1("DB")?
        .prepare(
            "INSERT INTO feedback (uid, category, body, route, app_version, platform) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )
        .bind(&[
            uid.into(),
            input.category.as_str().into(),
            input.body.into(),
            input.route.into(),
            input.app_version.into(),
            input.platform.into(),
        ])?
        .run()
        .await?;

    Ok(Response::from_json(&json!({ "ok": true }))?.with_status(201))
}
