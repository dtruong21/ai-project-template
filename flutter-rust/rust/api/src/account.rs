//! `DELETE /v1/account` — erase everything stored for the caller.
//!
//! App Store and Play both require in-app account deletion that actually
//! deletes. **Every table that has a `uid` column must be listed here** —
//! `/d1` adds new tables to this list; check it when adding one by hand.
//!
//! The Firebase Auth user itself is deleted by the app afterwards
//! (`FirebaseAuth.instance.currentUser.delete()`): call this route first,
//! while the token is still valid.

use worker::{Request, Response, Result, RouteContext};

use crate::{auth, http};

/// One statement per table that has a `uid` column.
const DELETE_USER_ROWS: &[&str] = &[
    "DELETE FROM feedback WHERE uid = ?1",
    "DELETE FROM profiles WHERE uid = ?1",
    // modules: user-tables
];

pub async fn delete(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let uid = match auth::uid_from_request(&req, &ctx.env).await {
        Ok(uid) => uid,
        Err(reason) => return http::unauthenticated(reason),
    };

    // modules: before-delete

    let db = ctx.env.d1("DB")?;
    let mut statements = Vec::with_capacity(DELETE_USER_ROWS.len());
    for sql in DELETE_USER_ROWS {
        statements.push(db.prepare(*sql).bind(&[uid.as_str().into()])?);
    }
    // One batch = one transaction: either every table is cleared or none is.
    db.batch(statements).await?;

    // Idempotent: deleting an account with no rows is still a success.
    http::no_content()
}
