//! Models and validation shared by the app (`core`) and the Worker (`api`).
//!
//! One rule lives in one place: the app validates before sending, the Worker
//! validates again before writing (never trust the client), and both call the
//! same function.

use std::fmt;

use serde::{Deserialize, Serialize};

pub const FEEDBACK_BODY_MAX_CHARS: usize = 2000;
pub const SHORT_FIELD_MAX_CHARS: usize = 200;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FeedbackCategory {
    Bug,
    Idea,
    Praise,
    Other,
}

impl FeedbackCategory {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Bug => "bug",
            Self::Idea => "idea",
            Self::Praise => "praise",
            Self::Other => "other",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "bug" => Some(Self::Bug),
            "idea" => Some(Self::Idea),
            "praise" => Some(Self::Praise),
            "other" => Some(Self::Other),
            _ => None,
        }
    }
}

/// Body of `POST /v1/feedback`. The user id is NOT part of it — the Worker
/// takes it from the verified auth token, never from the client.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NewFeedback {
    pub category: FeedbackCategory,
    pub body: String,
    pub route: String,
    pub app_version: String,
    pub platform: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValidationError {
    BodyEmpty,
    BodyTooLong,
    FieldTooLong(&'static str),
}

impl fmt::Display for ValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BodyEmpty => write!(f, "Feedback can't be empty."),
            Self::BodyTooLong => write!(
                f,
                "Feedback is too long (max {FEEDBACK_BODY_MAX_CHARS} characters)."
            ),
            Self::FieldTooLong(field) => write!(f, "Field `{field}` is too long."),
        }
    }
}

impl std::error::Error for ValidationError {}

impl NewFeedback {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self.body.trim().is_empty() {
            return Err(ValidationError::BodyEmpty);
        }
        if self.body.chars().count() > FEEDBACK_BODY_MAX_CHARS {
            return Err(ValidationError::BodyTooLong);
        }
        for (name, value) in [
            ("route", &self.route),
            ("app_version", &self.app_version),
            ("platform", &self.platform),
        ] {
            if value.chars().count() > SHORT_FIELD_MAX_CHARS {
                return Err(ValidationError::FieldTooLong(name));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn feedback(body: &str) -> NewFeedback {
        NewFeedback {
            category: FeedbackCategory::Bug,
            body: body.to_string(),
            route: "/home".to_string(),
            app_version: "1.0.0".to_string(),
            platform: "ios".to_string(),
        }
    }

    #[test]
    fn accepts_normal_feedback() {
        assert_eq!(feedback("Button does nothing").validate(), Ok(()));
    }

    #[test]
    fn rejects_blank_body() {
        assert_eq!(feedback("  \n ").validate(), Err(ValidationError::BodyEmpty));
    }

    #[test]
    fn body_limit_counts_characters_not_bytes() {
        // "é" is 2 bytes; the limit is in characters.
        let at_limit = "é".repeat(FEEDBACK_BODY_MAX_CHARS);
        assert_eq!(feedback(&at_limit).validate(), Ok(()));
        let over = "é".repeat(FEEDBACK_BODY_MAX_CHARS + 1);
        assert_eq!(feedback(&over).validate(), Err(ValidationError::BodyTooLong));
    }

    #[test]
    fn rejects_oversized_metadata() {
        let mut f = feedback("ok");
        f.route = "x".repeat(SHORT_FIELD_MAX_CHARS + 1);
        assert_eq!(f.validate(), Err(ValidationError::FieldTooLong("route")));
    }

    #[test]
    fn category_round_trips_as_lowercase_json() {
        for c in [
            FeedbackCategory::Bug,
            FeedbackCategory::Idea,
            FeedbackCategory::Praise,
            FeedbackCategory::Other,
        ] {
            assert_eq!(FeedbackCategory::parse(c.as_str()), Some(c));
            assert_eq!(
                serde_json::to_string(&c).unwrap(),
                format!("\"{}\"", c.as_str())
            );
        }
        assert_eq!(FeedbackCategory::parse("spam"), None);
    }

    #[test]
    fn rejects_unknown_json_fields() {
        // A client must not be able to smuggle `uid` in the body.
        let json = r#"{"category":"bug","body":"x","route":"/","app_version":"1","platform":"ios","uid":"someone-else"}"#;
        assert!(serde_json::from_str::<NewFeedback>(json).is_err());
    }
}
