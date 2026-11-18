//! App-side Rust, called from Dart through flutter_rust_bridge.
//!
//! After changing anything here: `flutter_rust_bridge_codegen generate`,
//! then fully restart the app (hot reload does not reload Rust).
//!
//! Rule for this crate: logic and data shaping only. No UI, no HTTP — Dart
//! owns the network call (`lib/core/api/api_client.dart`) so the app does not
//! carry a second TLS stack.

use shared::{FeedbackCategory, NewFeedback};

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
    fn invalid_input_never_produces_a_payload() {
        assert!(build("idea", "   ").is_err());
        assert!(build("spam", "hello").is_err());
    }
}
