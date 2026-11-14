//! `/v1/feedback` — the reference slice. Copy its shape for new tables.

use shared::{codes, page_size, Cursor, Feedback, NewFeedback, Page};
use worker::{Request, Response, Result, RouteContext};

use crate::{auth, http};

/// `POST /v1/feedback`
pub async fn create(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(input) = http::parse_body::<NewFeedback>(&mut req).await else {
        return http::invalid_body();
    };
    if let Err(e) = input.validate() {
        return http::error(422, codes::VALIDATION_FAILED, e.to_string());
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

    http::json(201, &serde_json::json!({ "ok": true }))
}

/// `GET /v1/feedback?limit=&cursor=` — the caller's own rows, newest first.
pub async fn list(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };

    let url = req.url()?;
    let param = |name: &str| {
        url.query_pairs()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.into_owned())
    };
    let limit = page_size(param("limit").as_deref());
    let cursor = match param("cursor") {
        None => None,
        Some(raw) => match Cursor::parse(&raw) {
            Some(cursor) => Some(cursor),
            None => return http::error(400, codes::INVALID_QUERY, "Invalid cursor."),
        },
    };

    // Ask for one extra row: its presence tells us there is a next page
    // without a second COUNT query (rows read are billed).
    let fetch = f64::from(limit + 1);
    let db = ctx.env.d1("DB")?;
    let statement = match &cursor {
        None => db
            .prepare(
                "SELECT id, category, body, route, app_version, platform, created_at \
                 FROM feedback WHERE uid = ?1 \
                 ORDER BY created_at DESC, id DESC LIMIT ?2",
            )
            .bind(&[uid.into(), fetch.into()])?,
        Some(cursor) => db
            .prepare(
                "SELECT id, category, body, route, app_version, platform, created_at \
                 FROM feedback WHERE uid = ?1 AND (created_at, id) < (?2, ?3) \
                 ORDER BY created_at DESC, id DESC LIMIT ?4",
            )
            .bind(&[
                uid.into(),
                // i64 → f64 is exact for any real timestamp (< 2^53).
                (cursor.created_at as f64).into(),
                cursor.id.as_str().into(),
                fetch.into(),
            ])?,
    };

    let mut items: Vec<Feedback> = statement.all().await?.results()?;
    let has_more = items.len() > limit as usize;
    items.truncate(limit as usize);
    let next_cursor = match (has_more, items.last()) {
        (true, Some(last)) => Some(
            Cursor {
                created_at: last.created_at,
                id: last.id.clone(),
            }
            .encode(),
        ),
        _ => None,
    };

    http::json(200, &Page { items, next_cursor })
}

/// `DELETE /v1/feedback/:id`
///
/// The `uid` condition is the ownership check: someone else's row and a row
/// that does not exist are indistinguishable (both 404), so ids cannot be
/// probed.
pub async fn delete(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(id) = ctx.param("id") else {
        return http::not_found();
    };

    let deleted: Option<serde_json::Value> = ctx
        .env
        .d1("DB")?
        .prepare("DELETE FROM feedback WHERE id = ?1 AND uid = ?2 RETURNING id")
        .bind(&[id.as_str().into(), uid.into()])?
        .first(None)
        .await?;

    match deleted {
        Some(_) => http::no_content(),
        None => http::not_found(),
    }
}
