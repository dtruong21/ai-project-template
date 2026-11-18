//! `/v1/profile` — the caller's own profile. There is no "get someone
//! else's profile" route; add one deliberately if a feature needs it, and
//! decide then which fields are public.

use shared::{codes, Profile, ProfileUpdate};
use worker::{Request, Response, Result, RouteContext};

use crate::{auth, http};

/// `GET /v1/profile` — 404 until the first `PUT`.
pub async fn get(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };

    let profile: Option<Profile> = ctx
        .env
        .d1("DB")?
        .prepare("SELECT display_name, created_at, updated_at FROM profiles WHERE uid = ?1")
        .bind(&[uid.into()])?
        .first(None)
        .await?;

    match profile {
        Some(profile) => http::json(200, &profile),
        None => http::not_found(),
    }
}

/// `PUT /v1/profile` — create or update (idempotent).
pub async fn put(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(input) = http::parse_body::<ProfileUpdate>(&mut req).await else {
        return http::invalid_body();
    };
    if let Err(e) = input.validate() {
        return http::error(422, codes::VALIDATION_FAILED, e.to_string());
    }

    let profile: Option<Profile> = ctx
        .env
        .d1("DB")?
        .prepare(
            "INSERT INTO profiles (uid, display_name) VALUES (?1, ?2) \
             ON CONFLICT (uid) DO UPDATE SET \
               display_name = excluded.display_name, updated_at = unixepoch() \
             RETURNING display_name, created_at, updated_at",
        )
        .bind(&[uid.into(), input.display_name.trim().into()])?
        .first(None)
        .await?;

    match profile {
        Some(profile) => http::json(200, &profile),
        None => Err(worker::Error::RustError(
            "profile upsert returned no row".into(),
        )),
    }
}
