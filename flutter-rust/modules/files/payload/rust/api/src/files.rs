//! Files module — `/v1/files`. Bytes live in R2 (binding `FILES`); a D1 row
//! per file holds ownership and metadata. The row is the source of truth: a
//! file is only reachable through a row owned by the caller.
//!
//! ponytail: uploads and downloads go through the Worker and are held in
//! memory (≤ 10 MB, well inside the 128 MB isolate limit). Past ~50 MB or
//! heavy traffic, switch to presigned R2 URLs so bytes skip the Worker.

use serde::Deserialize;
use shared::files::{
    self as rules, FileError, FileMeta, MAX_FILES_PER_USER, MAX_FILE_BYTES, QUOTA_EXCEEDED,
    TOO_LARGE,
};
use shared::{codes, page_size, Cursor, Page};
use worker::{console_error, Env, Headers, HttpMetadata, Request, Response, Result, RouteContext};

use crate::{auth, http};

const BUCKET: &str = "FILES";

fn too_large() -> Result<Response> {
    http::error(413, TOO_LARGE, FileError::TooLarge.to_string())
}

fn random_id() -> Result<String> {
    let mut bytes = [0u8; 16];
    getrandom::getrandom(&mut bytes)
        .map_err(|e| worker::Error::RustError(format!("no randomness: {e}")))?;
    Ok(bytes.iter().map(|b| format!("{b:02x}")).collect())
}

/// `POST /v1/files?name=photo.png` — the request body IS the file.
pub async fn create(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };

    // Refuse an oversized upload before reading a byte of it.
    let declared = req
        .headers()
        .get("Content-Length")?
        .and_then(|v| v.parse::<usize>().ok());
    if declared.is_some_and(|len| len > MAX_FILE_BYTES) {
        return too_large();
    }
    let bytes = req.bytes().await?;

    // Content-Length can lie or be absent (chunked): check the real size.
    let content_type = match rules::validate_upload(&bytes) {
        Ok(content_type) => content_type,
        Err(FileError::TooLarge) => return too_large(),
        Err(e) => return http::error(422, codes::VALIDATION_FAILED, e.to_string()),
    };
    let name = req
        .url()?
        .query_pairs()
        .find(|(key, _)| key == "name")
        .map(|(_, value)| rules::clean_name(&value))
        .unwrap_or_else(|| "file".to_string());

    let db = ctx.env.d1("DB")?;

    // ponytail: count-then-insert can overshoot the quota by a few under a
    // burst of parallel uploads. Enforce strictly with a trigger if it matters.
    let held: Option<serde_json::Value> = db
        .prepare("SELECT COUNT(*) AS n FROM files WHERE uid = ?1")
        .bind(&[uid.as_str().into()])?
        .first(None)
        .await?;
    let held = held
        .and_then(|row| row.get("n").and_then(|n| n.as_f64()))
        .unwrap_or(0.0) as u32;
    if held >= MAX_FILES_PER_USER {
        return http::error(
            403,
            QUOTA_EXCEEDED,
            format!("You can keep up to {MAX_FILES_PER_USER} files. Delete one to add another."),
        );
    }

    // Bytes first, row second: a crash in between leaves an unreachable
    // object (harmless, can be swept), never a row that points at nothing.
    let id = random_id()?;
    let size = bytes.len() as f64;
    let bucket = ctx.env.bucket(BUCKET)?;
    bucket
        .put(id.clone(), bytes)
        .http_metadata(HttpMetadata {
            content_type: Some(content_type.to_string()),
            ..Default::default()
        })
        .execute()
        .await?;

    let inserted: worker::Result<Option<FileMeta>> = db
        .prepare(
            "INSERT INTO files (id, uid, name, content_type, size) \
             VALUES (?1, ?2, ?3, ?4, ?5) \
             RETURNING id, name, content_type, size, created_at",
        )
        .bind(&[
            id.as_str().into(),
            uid.into(),
            name.into(),
            content_type.into(),
            size.into(),
        ])?
        .first(None)
        .await;

    match inserted {
        Ok(Some(meta)) => http::json(201, &meta),
        other => {
            if let Err(e) = bucket.delete(id).await {
                console_error!("could not clean up object after failed insert: {e}");
            }
            Err(other
                .err()
                .unwrap_or_else(|| worker::Error::RustError("file insert returned no row".into())))
        }
    }
}

/// `GET /v1/files?limit=&cursor=` — the caller's files, newest first.
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

    let fetch = f64::from(limit + 1);
    let db = ctx.env.d1("DB")?;
    let statement = match &cursor {
        None => db
            .prepare(
                "SELECT id, name, content_type, size, created_at \
                 FROM files WHERE uid = ?1 \
                 ORDER BY created_at DESC, id DESC LIMIT ?2",
            )
            .bind(&[uid.into(), fetch.into()])?,
        Some(cursor) => db
            .prepare(
                "SELECT id, name, content_type, size, created_at \
                 FROM files WHERE uid = ?1 AND (created_at, id) < (?2, ?3) \
                 ORDER BY created_at DESC, id DESC LIMIT ?4",
            )
            .bind(&[
                uid.into(),
                (cursor.created_at as f64).into(),
                cursor.id.as_str().into(),
                fetch.into(),
            ])?,
    };

    let mut items: Vec<FileMeta> = statement.all().await?.results()?;
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

#[derive(Deserialize)]
struct StoredType {
    name: String,
    content_type: String,
}

/// `GET /v1/files/:id` — the bytes. Someone else's file and a file that does
/// not exist are both 404.
pub async fn get(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(id) = ctx.param("id") else {
        return http::not_found();
    };

    let row: Option<StoredType> = ctx
        .env
        .d1("DB")?
        .prepare("SELECT name, content_type FROM files WHERE id = ?1 AND uid = ?2")
        .bind(&[id.as_str().into(), uid.into()])?
        .first(None)
        .await?;
    let Some(row) = row else {
        return http::not_found();
    };

    let object = ctx.env.bucket(BUCKET)?.get(id.clone()).execute().await?;
    let Some(object) = object else {
        // Row without an object: treat as gone rather than failing the request.
        console_error!("file row {id} has no R2 object");
        return http::not_found();
    };
    let Some(body) = object.body() else {
        return http::not_found();
    };
    let bytes = body.bytes().await?;

    let headers = Headers::new();
    // The type was sniffed from the bytes at upload, never taken from the client.
    headers.set("Content-Type", &row.content_type)?;
    headers.set("X-Content-Type-Options", "nosniff")?;
    // Even if a viewer misbehaves, the response can load and run nothing.
    headers.set("Content-Security-Policy", "default-src 'none'; sandbox")?;
    headers.set("Cache-Control", "private, no-store")?;
    if row.content_type == "application/pdf" {
        // The name was cleaned at upload to characters safe in a header.
        headers.set(
            "Content-Disposition",
            &format!("attachment; filename=\"{}\"", row.name),
        )?;
    }
    Ok(Response::from_bytes(bytes)?.with_headers(headers))
}

#[derive(Deserialize)]
struct IdRow {
    id: String,
}

/// `DELETE /v1/files/:id`
pub async fn delete(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };
    let Some(id) = ctx.param("id") else {
        return http::not_found();
    };

    // Row first: it is what grants access, so once it is gone the file is
    // unreachable even if the object delete below fails.
    let deleted: Option<IdRow> = ctx
        .env
        .d1("DB")?
        .prepare("DELETE FROM files WHERE id = ?1 AND uid = ?2 RETURNING id")
        .bind(&[id.as_str().into(), uid.into()])?
        .first(None)
        .await?;
    let Some(deleted) = deleted else {
        return http::not_found();
    };

    if let Err(e) = ctx.env.bucket(BUCKET)?.delete(deleted.id).await {
        console_error!("file row deleted but R2 delete failed: {e}");
    }
    http::no_content()
}

/// Deletes every R2 object the user owns. Called by `DELETE /v1/account`
/// BEFORE the rows are removed, so if this fails nothing is half-deleted and
/// the user can simply retry.
pub async fn purge_user(env: &Env, uid: &str) -> Result<()> {
    let rows: Vec<IdRow> = env
        .d1("DB")?
        .prepare("SELECT id FROM files WHERE uid = ?1")
        .bind(&[uid.into()])?
        .all()
        .await?
        .results()?;

    let bucket = env.bucket(BUCKET)?;
    // R2 deletes at most 1000 keys per call.
    for chunk in rows.chunks(1000) {
        bucket
            .delete_multiple(chunk.iter().map(|row| row.id.clone()).collect())
            .await?;
    }
    Ok(())
}
