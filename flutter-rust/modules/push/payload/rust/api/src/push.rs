//! Push module — device tokens, and sending through Firebase Cloud Messaging.
//!
//! Routes:
//!   PUT    /v1/push/token    register this device (signed-in user)
//!   DELETE /v1/push/token    remove this device  (signed-in user)
//!   POST   /v1/admin/push    send to one user    (operator key; off unless set)
//!
//! From your own Worker code, send with [`send_to_user`] — that is the real
//! entry point; the admin route is a thin wrapper for curl, dashboards, cron.
//!
//! Sending uses FCM HTTP v1, which needs a Google service account. The key
//! lives only in the `FCM_SERVICE_ACCOUNT` Worker secret. We sign a JWT with
//! it, trade that for a one-hour access token (cached per isolate), and call
//! FCM with the access token.
//!
//! ponytail: the RSA signing is pure Rust in wasm — tens of ms of CPU once
//! an hour per isolate. Fine on the Workers paid plan; the free plan's 10 ms
//! CPU cap can fail it. Switch to WebCrypto (`SubtleCrypto.sign`) if needed.

use std::cell::RefCell;
use std::rc::Rc;

use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use shared::codes;
use shared::push::{
    AdminSend, PushMessage, TokenRegistration, TokenRemoval, MAX_TOKENS_PER_USER, NOT_CONFIGURED,
};
use worker::wasm_bindgen::JsValue;
use worker::{
    console_error, Date, Env, Fetch, Headers, Method, Request, RequestInit, Response, Result,
    RouteContext,
};

use crate::{auth, http};

const SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const FCM_BASE: &str = "https://fcm.googleapis.com";
/// URL-encoded `urn:ietf:params:oauth:grant-type:jwt-bearer`.
const JWT_GRANT: &str = "urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer";
/// Renew this long before Google says the access token expires.
const REFRESH_MARGIN_MS: u64 = 5 * 60 * 1000;

/// A Worker secret in production; a plain var under `wrangler dev --var`.
fn config(env: &Env, name: &str) -> Option<String> {
    env.secret(name)
        .map(|s| s.to_string())
        .or_else(|_| env.var(name).map(|v| v.to_string()))
        .ok()
        .filter(|v| !v.is_empty())
}

#[derive(Deserialize)]
struct ServiceAccount {
    client_email: String,
    private_key: String,
    project_id: String,
    token_uri: String,
}

fn service_account(env: &Env) -> Option<ServiceAccount> {
    serde_json::from_str(&config(env, "FCM_SERVICE_ACCOUNT")?).ok()
}

thread_local! {
    /// `(expires_at_ms, access_token)`, per isolate.
    static ACCESS_TOKEN: RefCell<Option<(u64, Rc<String>)>> = const { RefCell::new(None) };
}

#[derive(Serialize)]
struct AssertionClaims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: u64,
    exp: u64,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
}

async fn access_token(account: &ServiceAccount) -> Result<Rc<String>> {
    let now_ms = Date::now().as_millis();
    let cached = ACCESS_TOKEN.with(|c| c.borrow().clone());
    if let Some((expires_at, token)) = cached {
        if now_ms + REFRESH_MARGIN_MS < expires_at {
            return Ok(token);
        }
    }

    let now = now_ms / 1000;
    let assertion = encode(
        &Header::new(Algorithm::RS256),
        &AssertionClaims {
            iss: &account.client_email,
            scope: SCOPE,
            aud: &account.token_uri,
            iat: now,
            exp: now + 3600,
        },
        &EncodingKey::from_rsa_pem(account.private_key.as_bytes())
            .map_err(|e| worker::Error::RustError(format!("bad service account key: {e}")))?,
    )
    .map_err(|e| worker::Error::RustError(format!("could not sign assertion: {e}")))?;

    let headers = Headers::new();
    headers.set("Content-Type", "application/x-www-form-urlencoded")?;
    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(JsValue::from_str(&format!(
            "grant_type={JWT_GRANT}&assertion={assertion}"
        ))));
    let mut response = Fetch::Request(Request::new_with_init(&account.token_uri, &init)?)
        .send()
        .await?;
    if response.status_code() != 200 {
        return Err(worker::Error::RustError(format!(
            "token exchange failed: HTTP {}",
            response.status_code()
        )));
    }
    let parsed: TokenResponse = response.json().await?;

    let token = Rc::new(parsed.access_token);
    ACCESS_TOKEN.with(|c| {
        *c.borrow_mut() = Some((now_ms + parsed.expires_in * 1000, token.clone()));
    });
    Ok(token)
}

#[derive(Debug, PartialEq, Eq)]
enum Outcome {
    Sent,
    /// FCM says the token is dead (app uninstalled, token rotated).
    Dead,
    Failed,
}

async fn send_one(
    env: &Env,
    account: &ServiceAccount,
    access: &str,
    token: &str,
    message: &PushMessage,
) -> Outcome {
    let base = config(env, "FCM_BASE_URL").unwrap_or_else(|| FCM_BASE.to_string());
    let url = format!("{base}/v1/projects/{}/messages:send", account.project_id);
    let body = serde_json::json!({
        "message": {
            "token": token,
            "notification": { "title": message.title.trim(), "body": message.body.trim() },
            "data": message.data,
        }
    });

    let result: Result<(u16, String)> = async {
        let headers = Headers::new();
        headers.set("Authorization", &format!("Bearer {access}"))?;
        headers.set("Content-Type", "application/json")?;
        let mut init = RequestInit::new();
        init.with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(JsValue::from_str(&body.to_string())));
        let mut response = Fetch::Request(Request::new_with_init(&url, &init)?)
            .send()
            .await?;
        Ok((
            response.status_code(),
            response.text().await.unwrap_or_default(),
        ))
    }
    .await;

    match result {
        Ok((200, _)) => Outcome::Sent,
        // UNREGISTERED is a 404 from FCM.
        Ok((404, _)) => Outcome::Dead,
        Ok((status, text)) if text.contains("UNREGISTERED") => {
            let _ = status;
            Outcome::Dead
        }
        Ok((401, _)) => {
            // Our access token was refused: drop it so the next send mints a new one.
            ACCESS_TOKEN.with(|c| *c.borrow_mut() = None);
            console_error!("FCM rejected the access token");
            Outcome::Failed
        }
        Ok((status, text)) => {
            console_error!(
                "FCM send failed: HTTP {status}: {}",
                text.chars().take(300).collect::<String>()
            );
            Outcome::Failed
        }
        Err(e) => {
            console_error!("FCM send error: {e}");
            Outcome::Failed
        }
    }
}

#[derive(Debug, Default, Serialize)]
pub struct SendReport {
    pub sent: u32,
    /// Dead tokens, deleted from the table.
    pub removed: u32,
    pub failed: u32,
}

#[derive(Deserialize)]
struct TokenRow {
    token: String,
}

/// Sends `message` to every device the user has registered. `Err` only when
/// push is not configured or the database fails; per-device failures are
/// counted in the report instead.
pub async fn send_to_user(env: &Env, uid: &str, message: &PushMessage) -> Result<SendReport> {
    let account =
        service_account(env).ok_or_else(|| worker::Error::RustError(NOT_CONFIGURED.into()))?;

    let db = env.d1("DB")?;
    let rows: Vec<TokenRow> = db
        .prepare("SELECT token FROM push_tokens WHERE uid = ?1 ORDER BY updated_at DESC LIMIT ?2")
        .bind(&[uid.into(), f64::from(MAX_TOKENS_PER_USER).into()])?
        .all()
        .await?
        .results()?;

    let mut report = SendReport::default();
    if rows.is_empty() {
        return Ok(report);
    }

    let access = access_token(&account).await?;
    for row in rows {
        match send_one(env, &account, &access, &row.token, message).await {
            Outcome::Sent => report.sent += 1,
            Outcome::Failed => report.failed += 1,
            Outcome::Dead => {
                report.removed += 1;
                // Only delete if it is still this user's: it may have moved.
                db.prepare("DELETE FROM push_tokens WHERE token = ?1 AND uid = ?2")
                    .bind(&[row.token.as_str().into(), uid.into()])?
                    .run()
                    .await?;
            }
        }
    }
    Ok(report)
}

/// `PUT /v1/push/token`
pub async fn register(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(input) = http::parse_body::<TokenRegistration>(&mut req).await else {
        return http::invalid_body();
    };
    if let Err(e) = input.validate() {
        return http::error(422, codes::VALIDATION_FAILED, e.to_string());
    }

    let db = ctx.env.d1("DB")?;
    // One batch = one transaction. Upsert, then trim to the newest N so a
    // client cannot grow the table without bound.
    db.batch(vec![
        db.prepare(
            "INSERT INTO push_tokens (token, uid, platform) VALUES (?1, ?2, ?3) \
             ON CONFLICT (token) DO UPDATE SET \
               uid = excluded.uid, platform = excluded.platform, updated_at = unixepoch()",
        )
        .bind(&[
            input.token.as_str().into(),
            uid.as_str().into(),
            input.platform.as_str().into(),
        ])?,
        db.prepare(
            "DELETE FROM push_tokens WHERE uid = ?1 AND token NOT IN (\
               SELECT token FROM push_tokens WHERE uid = ?1 \
               ORDER BY updated_at DESC, token DESC LIMIT ?2)",
        )
        .bind(&[uid.as_str().into(), f64::from(MAX_TOKENS_PER_USER).into()])?,
    ])
    .await?;
    http::no_content()
}

/// `DELETE /v1/push/token` — idempotent. Removing a token that is missing or
/// belongs to someone else is a no-op, never an error: nothing to probe.
pub async fn unregister(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(input) = http::parse_body::<TokenRemoval>(&mut req).await else {
        return http::invalid_body();
    };
    if let Err(e) = input.validate() {
        return http::error(422, codes::VALIDATION_FAILED, e.to_string());
    }
    ctx.env
        .d1("DB")?
        .prepare("DELETE FROM push_tokens WHERE token = ?1 AND uid = ?2")
        .bind(&[input.token.as_str().into(), uid.into()])?
        .run()
        .await?;
    http::no_content()
}

/// Same length-independent comparison cost for equal-length inputs.
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// `POST /v1/admin/push` — for operators, not users. Off (404) unless the
/// `PUSH_ADMIN_KEY` secret is set; then needs `X-Admin-Key: <that value>`.
/// Anyone holding the key can notify any user: treat it like a root password,
/// and prefer calling [`send_to_user`] from your own Worker code.
pub async fn admin_send(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let Some(expected) = config(&ctx.env, "PUSH_ADMIN_KEY") else {
        return http::not_found();
    };
    let given = req.headers().get("X-Admin-Key")?.unwrap_or_default();
    if !constant_time_eq(given.as_bytes(), expected.as_bytes()) {
        return http::unauthenticated("Invalid admin key.".to_string());
    }

    let Some(input) = http::parse_body::<AdminSend>(&mut req).await else {
        return http::invalid_body();
    };
    if let Err(e) = input.validate() {
        return http::error(422, codes::VALIDATION_FAILED, e.to_string());
    }

    match send_to_user(&ctx.env, &input.uid, &input.message()).await {
        Ok(report) => http::json(200, &report),
        Err(worker::Error::RustError(reason)) if reason == NOT_CONFIGURED => http::error(
            503,
            NOT_CONFIGURED,
            "Push is not configured: set the FCM_SERVICE_ACCOUNT secret.",
        ),
        Err(e) => Err(e),
    }
}
