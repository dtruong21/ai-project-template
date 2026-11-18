//! Payments module — entitlements from RevenueCat.
//!
//! The stores sell; RevenueCat validates receipts; this Worker keeps one row
//! per (user, entitlement) and is the ONLY thing that decides whether a user
//! is paid. The app asks "do I have `pro`?" by reading what the Worker holds —
//! it can never grant itself anything.
//!
//! Routes:
//!   GET  /v1/entitlements              the caller's entitlements
//!   POST /v1/entitlements/refresh      re-read them from RevenueCat now
//!   GET  /v1/pro/ping                  EXAMPLE of gating a route (replace it)
//!   POST /v1/webhooks/revenuecat       RevenueCat → us (shared-secret header)
//!
//! Keeping state right: a webhook only says "this user changed". We then ask
//! RevenueCat's REST API for the user's current state and overwrite our rows,
//! so duplicate, late and out-of-order events cannot leave us wrong. If that
//! lookup fails we answer 500 and RevenueCat retries the webhook.
//!
//! In your own routes, gate a feature with [`has_entitlement`].

use serde::Serialize;
use shared::payments::{
    is_active, EntitlementList, EntitlementRow, EntitlementView, SubscriberResponse,
    WebhookEnvelope, NOT_CONFIGURED, PAYMENT_REQUIRED, UPSTREAM_UNAVAILABLE,
};
use worker::wasm_bindgen::JsValue;
use worker::{
    console_error, js_sys, Date, Env, Fetch, Headers, Method, Request, RequestInit, Response,
    Result, RouteContext,
};

use crate::{auth, http};

const RC_BASE: &str = "https://api.revenuecat.com";
/// Minimum seconds between refreshes from RevenueCat for one user.
const REFRESH_MIN_INTERVAL_S: i64 = 5;

fn config(env: &Env, name: &str) -> Option<String> {
    env.secret(name)
        .map(|s| s.to_string())
        .or_else(|_| env.var(name).map(|v| v.to_string()))
        .ok()
        .filter(|v| !v.is_empty())
}

fn now_s() -> i64 {
    (Date::now().as_millis() / 1000) as i64
}

fn rc_url(env: &Env, uid: &str) -> String {
    let base = config(env, "REVENUECAT_BASE_URL").unwrap_or_else(|| RC_BASE.to_string());
    let id = String::from(js_sys::encode_uri_component(uid));
    format!("{base}/v1/subscribers/{id}")
}

async fn rc_call(env: &Env, uid: &str, method: Method) -> Result<(u16, String)> {
    let key = config(env, "REVENUECAT_API_KEY")
        .ok_or_else(|| worker::Error::RustError(NOT_CONFIGURED.into()))?;
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {key}"))?;
    headers.set("Content-Type", "application/json")?;
    let mut init = RequestInit::new();
    init.with_method(method).with_headers(headers);
    let mut response = Fetch::Request(Request::new_with_init(&rc_url(env, uid), &init)?)
        .send()
        .await?;
    Ok((
        response.status_code(),
        response.text().await.unwrap_or_default(),
    ))
}

/// Re-reads one user's entitlements from RevenueCat and replaces our rows.
async fn sync_user(env: &Env, uid: &str) -> Result<()> {
    let (status, text) = rc_call(env, uid, Method::Get).await?;
    if status != 200 {
        return Err(worker::Error::RustError(format!(
            "RevenueCat answered HTTP {status}"
        )));
    }
    let parsed: SubscriberResponse = serde_json::from_str(&text)
        .map_err(|e| worker::Error::RustError(format!("unreadable RevenueCat response: {e}")))?;
    let rows = parsed.subscriber.entitlement_rows();

    let db = env.d1("DB")?;
    let mut statements = vec![db
        .prepare("DELETE FROM entitlements WHERE uid = ?1")
        .bind(&[uid.into()])?];
    for EntitlementRow {
        name,
        expires_at,
        product,
        store,
    } in rows
    {
        statements.push(
            db.prepare(
                "INSERT INTO entitlements (uid, name, expires_at, product, store) \
                 VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .bind(&[
                uid.into(),
                name.into(),
                expires_at
                    .map(|at| at as f64)
                    .map_or(JsValue::NULL, JsValue::from_f64)
                    .into(),
                product
                    .map_or(JsValue::NULL, |p| JsValue::from_str(&p))
                    .into(),
                store
                    .map_or(JsValue::NULL, |s| JsValue::from_str(&s))
                    .into(),
            ])?,
        );
    }
    statements.push(
        db.prepare(
            "INSERT INTO customers (uid, synced_at) VALUES (?1, ?2) \
             ON CONFLICT (uid) DO UPDATE SET synced_at = excluded.synced_at",
        )
        .bind(&[uid.into(), (now_s() as f64).into()])?,
    );
    // One batch = one transaction: readers never see a half-written state.
    db.batch(statements).await?;
    Ok(())
}

#[derive(serde::Deserialize)]
struct Row {
    name: String,
    expires_at: Option<f64>,
    product: Option<String>,
}

async fn load(env: &Env, uid: &str) -> Result<Vec<EntitlementView>> {
    let rows: Vec<Row> = env
        .d1("DB")?
        .prepare("SELECT name, expires_at, product FROM entitlements WHERE uid = ?1 ORDER BY name")
        .bind(&[uid.into()])?
        .all()
        .await?
        .results()?;
    let now = now_s();
    Ok(rows
        .into_iter()
        .map(|row| {
            let expires_at = row.expires_at.map(|at| at as i64);
            EntitlementView {
                name: row.name,
                active: is_active(expires_at, now),
                expires_at,
                product: row.product,
            }
        })
        .collect())
}

/// Does `uid` hold an active `name` entitlement right now? Use this to gate
/// premium features on the server.
pub async fn has_entitlement(env: &Env, uid: &str, name: &str) -> Result<bool> {
    Ok(load(env, uid)
        .await?
        .iter()
        .any(|e| e.name == name && e.active))
}

/// `GET /v1/entitlements`
pub async fn list(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    http::json(
        200,
        &EntitlementList {
            entitlements: load(&ctx.env, &uid).await?,
        },
    )
}

/// `POST /v1/entitlements/refresh` — call right after a purchase so the app
/// need not wait for the webhook. Throttled: inside the minimum interval it
/// just returns what we already hold.
pub async fn refresh(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    if config(&ctx.env, "REVENUECAT_API_KEY").is_none() {
        return http::error(
            503,
            NOT_CONFIGURED,
            "Payments are not configured: set the REVENUECAT_API_KEY secret.",
        );
    }

    let last: Option<serde_json::Value> = ctx
        .env
        .d1("DB")?
        .prepare("SELECT synced_at FROM customers WHERE uid = ?1")
        .bind(&[uid.as_str().into()])?
        .first(None)
        .await?;
    let last = last
        .and_then(|row| row.get("synced_at").and_then(|v| v.as_f64()))
        .unwrap_or(0.0) as i64;

    if now_s() - last >= REFRESH_MIN_INTERVAL_S {
        if let Err(e) = sync_user(&ctx.env, &uid).await {
            console_error!("refresh failed for a user: {e}");
            return http::error(
                502,
                UPSTREAM_UNAVAILABLE,
                "Couldn't check your purchases right now. Try again in a moment.",
            );
        }
    }
    http::json(
        200,
        &EntitlementList {
            entitlements: load(&ctx.env, &uid).await?,
        },
    )
}

#[derive(Serialize)]
struct Ping {
    ok: bool,
}

/// `GET /v1/pro/ping` — the pattern for gating a feature. Copy this shape;
/// delete this route when you have a real one.
pub async fn pro_ping(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    if !has_entitlement(&ctx.env, &uid, "pro").await? {
        return http::error(402, PAYMENT_REQUIRED, "This needs an active subscription.");
    }
    http::json(200, &Ping { ok: true })
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// `POST /v1/webhooks/revenuecat`. RevenueCat sends the `Authorization`
/// header exactly as you typed it in its dashboard; we compare it, in constant
/// time, to the `REVENUECAT_WEBHOOK_SECRET` secret. Unset secret = route is off.
pub async fn webhook(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let Some(expected) = config(&ctx.env, "REVENUECAT_WEBHOOK_SECRET") else {
        return http::not_found();
    };
    let given = req.headers().get("Authorization")?.unwrap_or_default();
    if !constant_time_eq(given.as_bytes(), expected.as_bytes()) {
        return http::unauthenticated("Invalid webhook credentials.".to_string());
    }

    let Some(envelope) = http::parse_body::<WebhookEnvelope>(&mut req).await else {
        return http::invalid_body();
    };

    let users = envelope.event.users_to_refresh();
    for uid in &users {
        // `?`: a failed lookup answers 500, so RevenueCat retries the event.
        sync_user(&ctx.env, uid).await?;
    }
    http::json(200, &serde_json::json!({ "refreshed": users.len() }))
}

/// Erases the user at RevenueCat (their purchase history and aliases), for
/// `DELETE /v1/account`. Best effort: a failure is logged and never blocks
/// the deletion. NOTE: this does not cancel a store subscription — only the
/// user can, in their App Store / Google Play account.
pub async fn forget_user(env: &Env, uid: &str) {
    if config(env, "REVENUECAT_API_KEY").is_none() {
        return;
    }
    match rc_call(env, uid, Method::Delete).await {
        Ok((status, _)) if (200..300).contains(&status) || status == 404 => {}
        Ok((status, _)) => console_error!("RevenueCat delete answered HTTP {status}"),
        Err(e) => console_error!("RevenueCat delete failed: {e}"),
    }
}
