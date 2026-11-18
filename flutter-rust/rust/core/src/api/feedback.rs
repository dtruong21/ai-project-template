//! App-side Rust, called from Dart through flutter_rust_bridge.
//!
//! After changing anything here: `flutter_rust_bridge_codegen generate`,
//! then fully restart the app (hot reload does not reload Rust).
//!
//! Rule for this crate: logic and data shaping only. No UI, no HTTP — Dart
//! owns the network call (`lib/core/api/api_client.dart`) so the app does not
//! carry a second TLS stack.

use shared::{Feedback, FeedbackCategory, NewFeedback, Page};

/// Validates feedback with the same rules the Worker enforces and returns the
/// JSON body to POST to `/v1/feedback`.
///
/// On invalid input the `Err` string is user-facing; flutter_rust_bridge
/// surfaces it in Dart as a thrown exception.
#[flutter_rust_bridge::frb(sync)]
pub fn build_feedback_payload(
    category: String,
    body: String,
    route: String,
    app_version: String,
    platform: String,
) -> Result<String, String> {
    let category = FeedbackCategory::parse(&category)
        .ok_or_else(|| format!("Unknown feedback category `{category}`."))?;
    let feedback = NewFeedback {
        category,
        body: body.trim().to_string(),
        route,
        app_version,
        platform,
    };
    feedback.validate().map_err(|e| e.to_string())?;
    serde_json::to_string(&feedback).map_err(|e| e.to_string())
}

/// One row of the caller's feedback, as the UI needs it.
pub struct FeedbackItem {
    pub id: String,
    /// `bug` | `idea` | `praise` | `other`
    pub category: String,
    pub body: String,
    pub route: String,
    /// Seconds since epoch, UTC.
    pub created_at: i64,
}

pub struct FeedbackPage {
    pub items: Vec<FeedbackItem>,
    /// Pass back as `?cursor=` for the next page; `None` on the last page.
    pub next_cursor: Option<String>,
}

/// Parses the body of `GET /v1/feedback`. Decoding lives here, next to the
/// encoding, so the wire format is defined once (`rust/shared`) and Dart
/// never hand-parses JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_feedback_page(json: String) -> Result<FeedbackPage, String> {
    let page: Page<Feedback> =
        serde_json::from_str(&json).map_err(|_| "Unexpected response from the server.")?;
    Ok(FeedbackPage {
        items: page
            .items
            .into_iter()
            .map(|f| FeedbackItem {
                id: f.id,
                category: f.category.as_str().to_string(),
                body: f.body,
                route: f.route,
                created_at: f.created_at,
            })
            .collect(),
        next_cursor: page.next_cursor,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn build(category: &str, body: &str) -> Result<String, String> {
        build_feedback_payload(
            category.to_string(),
            body.to_string(),
            "/home".to_string(),
            "1.0.0".to_string(),
            "ios".to_string(),
        )
    }

    #[test]
    fn payload_is_what_the_worker_parses() {
        let json = build("idea", "  dark mode please  ").unwrap();
        let parsed: NewFeedback = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.category, FeedbackCategory::Idea);
        assert_eq!(parsed.body, "dark mode please");
    }

    #[test]
    fn parses_a_page_from_the_worker() {
        let json = r#"{"items":[{"id":"ab12","category":"bug","body":"x","route":"/",
            "app_version":"1","platform":"ios","created_at":1700000000}],"next_cursor":"1700000000_ab12"}"#;
        let page = parse_feedback_page(json.to_string()).unwrap();
        assert_eq!(page.items.len(), 1);
        assert_eq!(page.items[0].category, "bug");
        assert_eq!(page.items[0].created_at, 1_700_000_000);
        assert_eq!(page.next_cursor.as_deref(), Some("1700000000_ab12"));
    }

    #[test]
    fn a_bad_response_is_an_error_not_a_panic() {
        for bad in ["", "<html>", "{}", r#"{"items":[{"id":1}]}"#] {
            assert!(parse_feedback_page(bad.to_string()).is_err(), "{bad}");
        }
    }

    #[test]
    fn invalid_input_never_produces_a_payload() {
        assert!(build("idea", "   ").is_err());
        assert!(build("spam", "hello").is_err());
    }
}
