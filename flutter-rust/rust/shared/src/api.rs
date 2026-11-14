//! Wire conventions every endpoint shares: the error envelope and paging.

use serde::{Deserialize, Serialize};

/// Every non-2xx response body is `{"error": {"code": ..., "message": ...}}`.
///
/// `code` is stable and machine-readable (clients branch on it). `message` is
/// written for the end user and may be shown as-is. Never put internals
/// (SQL, stack traces, crate error text) in `message`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApiErrorBody {
    pub error: ApiError,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApiError {
    pub code: String,
    pub message: String,
}

impl ApiErrorBody {
    pub fn new(code: &str, message: impl Into<String>) -> Self {
        Self {
            error: ApiError {
                code: code.to_string(),
                message: message.into(),
            },
        }
    }
}

/// The complete set of error codes. Add here first, then use.
pub mod codes {
    /// 401 — missing, malformed, expired or forged token.
    pub const UNAUTHENTICATED: &str = "unauthenticated";
    /// 400 — body is not the JSON this route expects (includes unknown fields).
    pub const INVALID_BODY: &str = "invalid_body";
    /// 400 — a query parameter is malformed (e.g. a bad cursor).
    pub const INVALID_QUERY: &str = "invalid_query";
    /// 422 — body parsed but broke a `validate()` rule. `message` says which.
    pub const VALIDATION_FAILED: &str = "validation_failed";
    /// 404 — no such route, or no such row *owned by the caller*.
    pub const NOT_FOUND: &str = "not_found";
    /// 500 — anything unexpected. Details go to the Worker log, not the client.
    pub const INTERNAL: &str = "internal";
}

pub const PAGE_SIZE_DEFAULT: u32 = 20;
pub const PAGE_SIZE_MAX: u32 = 50;

/// One page of a list endpoint. `next_cursor` is `None` on the last page;
/// otherwise pass it back as `?cursor=` to get the next one.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Page<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<String>,
}

/// Turns the raw `?limit=` value into a safe page size: default when absent
/// or unparseable, never 0, never above [`PAGE_SIZE_MAX`]. A client cannot
/// make the Worker read an unbounded number of rows.
pub fn page_size(raw: Option<&str>) -> u32 {
    raw.and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(PAGE_SIZE_DEFAULT)
        .clamp(1, PAGE_SIZE_MAX)
}

/// Keyset cursor for lists ordered by `created_at DESC, id DESC`.
///
/// Keyset (not OFFSET) so page N costs the same rows-read as page 1, and rows
/// inserted while the user scrolls never cause duplicates or gaps.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Cursor {
    pub created_at: i64,
    pub id: String,
}

impl Cursor {
    pub fn encode(&self) -> String {
        format!("{}_{}", self.created_at, self.id)
    }

    /// `None` for anything that is not exactly what [`Cursor::encode`]
    /// produces. The parts are only ever used as bound SQL parameters.
    pub fn parse(raw: &str) -> Option<Self> {
        let (created_at, id) = raw.split_once('_')?;
        let created_at = created_at.parse::<i64>().ok()?;
        let id_ok = !id.is_empty() && id.len() <= 64 && id.chars().all(|c| c.is_ascii_hexdigit());
        id_ok.then(|| Self {
            created_at,
            id: id.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_body_has_the_documented_shape() {
        let json =
            serde_json::to_string(&ApiErrorBody::new(codes::NOT_FOUND, "Not found.")).unwrap();
        assert_eq!(
            json,
            r#"{"error":{"code":"not_found","message":"Not found."}}"#
        );
    }

    #[test]
    fn page_size_is_always_within_bounds() {
        assert_eq!(page_size(None), PAGE_SIZE_DEFAULT);
        assert_eq!(page_size(Some("10")), 10);
        assert_eq!(page_size(Some("0")), 1);
        assert_eq!(page_size(Some("999999")), PAGE_SIZE_MAX);
        assert_eq!(page_size(Some("-5")), PAGE_SIZE_DEFAULT);
        assert_eq!(page_size(Some("abc")), PAGE_SIZE_DEFAULT);
    }

    #[test]
    fn cursor_round_trips() {
        let cursor = Cursor {
            created_at: 1_700_000_000,
            id: "0af3".to_string(),
        };
        assert_eq!(Cursor::parse(&cursor.encode()), Some(cursor));
    }

    #[test]
    fn cursor_rejects_anything_unexpected() {
        for bad in [
            "",
            "123",
            "_abc",
            "123_",
            "abc_def",
            "123_xyz",
            "123_ab'; DROP TABLE feedback;--",
        ] {
            assert_eq!(Cursor::parse(bad), None, "accepted {bad:?}");
        }
    }
}
