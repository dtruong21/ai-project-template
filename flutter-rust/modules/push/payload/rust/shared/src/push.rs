//! Push module — rules shared by the app and the Worker.

use std::collections::BTreeMap;
use std::fmt;

use serde::{Deserialize, Serialize};

pub const MAX_TOKENS_PER_USER: u32 = 10;
pub const TOKEN_MAX_CHARS: usize = 512;
pub const TITLE_MAX_CHARS: usize = 80;
pub const BODY_MAX_CHARS: usize = 240;
pub const DATA_MAX_KEYS: usize = 10;
pub const DATA_KEY_MAX_CHARS: usize = 40;
pub const DATA_VALUE_MAX_CHARS: usize = 200;
pub const UID_MAX_CHARS: usize = 128;

/// Error `code` this module adds to the API's error envelope.
pub const NOT_CONFIGURED: &str = "push_not_configured";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    Ios,
    Android,
    Macos,
    Windows,
    Web,
}

impl Platform {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Ios => "ios",
            Self::Android => "android",
            Self::Macos => "macos",
            Self::Windows => "windows",
            Self::Web => "web",
        }
    }

    /// Case-insensitive, so Dart's `defaultTargetPlatform.name` ("iOS") works.
    pub fn parse(value: &str) -> Option<Self> {
        match value.to_ascii_lowercase().as_str() {
            "ios" => Some(Self::Ios),
            "android" => Some(Self::Android),
            "macos" => Some(Self::Macos),
            "windows" => Some(Self::Windows),
            "web" => Some(Self::Web),
            _ => None,
        }
    }
}

/// Body of `PUT /v1/push/token`. The uid comes from the auth token.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TokenRegistration {
    pub token: String,
    pub platform: Platform,
}

/// Body of `DELETE /v1/push/token`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TokenRemoval {
    pub token: String,
}

/// What a notification says. `data` is delivered to the app as strings.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PushMessage {
    pub title: String,
    pub body: String,
    #[serde(default)]
    pub data: BTreeMap<String, String>,
}

/// Body of the operator-only `POST /v1/admin/push`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdminSend {
    pub uid: String,
    pub title: String,
    pub body: String,
    #[serde(default)]
    pub data: BTreeMap<String, String>,
}

impl AdminSend {
    pub fn message(&self) -> PushMessage {
        PushMessage {
            title: self.title.clone(),
            body: self.body.clone(),
            data: self.data.clone(),
        }
    }

    pub fn validate(&self) -> Result<(), PushError> {
        if self.uid.is_empty() || self.uid.chars().count() > UID_MAX_CHARS {
            return Err(PushError::UidInvalid);
        }
        self.message().validate()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PushError {
    TokenInvalid,
    UidInvalid,
    TitleEmpty,
    TitleTooLong,
    BodyEmpty,
    BodyTooLong,
    DataTooLarge,
    DataKeyInvalid,
    DataValueTooLong,
}

impl fmt::Display for PushError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::TokenInvalid => write!(f, "That device token is not valid."),
            Self::UidInvalid => write!(f, "The user id is not valid."),
            Self::TitleEmpty => write!(f, "A notification needs a title."),
            Self::TitleTooLong => write!(f, "The title is too long (max {TITLE_MAX_CHARS} characters)."),
            Self::BodyEmpty => write!(f, "A notification needs text."),
            Self::BodyTooLong => write!(f, "The text is too long (max {BODY_MAX_CHARS} characters)."),
            Self::DataTooLarge => write!(f, "Too many data fields (max {DATA_MAX_KEYS})."),
            Self::DataKeyInvalid => write!(
                f,
                "Data keys may use letters, digits and _ only, up to {DATA_KEY_MAX_CHARS} characters, \
                 and may not start with google or gcm."
            ),
            Self::DataValueTooLong => write!(f, "A data value is too long (max {DATA_VALUE_MAX_CHARS} characters)."),
        }
    }
}

impl std::error::Error for PushError {}

/// FCM tokens are letters, digits and `: _ - .`. Anything else is not one.
pub fn validate_token(token: &str) -> Result<(), PushError> {
    let ok = !token.is_empty()
        && token.chars().count() <= TOKEN_MAX_CHARS
        && token
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, ':' | '_' | '-' | '.'));
    if ok {
        Ok(())
    } else {
        Err(PushError::TokenInvalid)
    }
}

impl TokenRegistration {
    pub fn validate(&self) -> Result<(), PushError> {
        validate_token(&self.token)
    }
}

impl TokenRemoval {
    pub fn validate(&self) -> Result<(), PushError> {
        validate_token(&self.token)
    }
}

/// Keys FCM reserves for itself; sending one is rejected by Google.
fn reserved_key(key: &str) -> bool {
    let lower = key.to_ascii_lowercase();
    lower.starts_with("google")
        || lower.starts_with("gcm")
        || matches!(lower.as_str(), "from" | "message_type" | "collapse_key")
}

impl PushMessage {
    pub fn validate(&self) -> Result<(), PushError> {
        let title = self.title.trim();
        if title.is_empty() {
            return Err(PushError::TitleEmpty);
        }
        if title.chars().count() > TITLE_MAX_CHARS {
            return Err(PushError::TitleTooLong);
        }
        let body = self.body.trim();
        if body.is_empty() {
            return Err(PushError::BodyEmpty);
        }
        if body.chars().count() > BODY_MAX_CHARS {
            return Err(PushError::BodyTooLong);
        }
        if self.data.len() > DATA_MAX_KEYS {
            return Err(PushError::DataTooLarge);
        }
        for (key, value) in &self.data {
            let key_ok = !key.is_empty()
                && key.chars().count() <= DATA_KEY_MAX_CHARS
                && key.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
                && !reserved_key(key);
            if !key_ok {
                return Err(PushError::DataKeyInvalid);
            }
            if value.chars().count() > DATA_VALUE_MAX_CHARS {
                return Err(PushError::DataValueTooLong);
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn message(title: &str, body: &str) -> PushMessage {
        PushMessage {
            title: title.into(),
            body: body.into(),
            data: BTreeMap::new(),
        }
    }

    #[test]
    fn accepts_realistic_fcm_tokens() {
        let token = "dXyz1:APA91bH_k-3.example";
        assert_eq!(validate_token(token), Ok(()));
        assert_eq!(validate_token(&"a".repeat(TOKEN_MAX_CHARS)), Ok(()));
    }

    #[test]
    fn rejects_tokens_that_cannot_be_fcm_tokens() {
        for bad in [
            "",
            "has space",
            "new\nline",
            "quote\"",
            "emoji😀",
            "../etc",
            &"a".repeat(TOKEN_MAX_CHARS + 1),
        ] {
            assert_eq!(validate_token(bad), Err(PushError::TokenInvalid), "{bad:?}");
        }
    }

    #[test]
    fn platform_parses_case_insensitively() {
        assert_eq!(Platform::parse("iOS"), Some(Platform::Ios));
        assert_eq!(Platform::parse("android"), Some(Platform::Android));
        assert_eq!(Platform::parse("linux"), None);
        assert_eq!(serde_json::to_string(&Platform::Ios).unwrap(), "\"ios\"");
    }

    #[test]
    fn message_needs_title_and_text() {
        assert_eq!(message("Hi", "There").validate(), Ok(()));
        assert_eq!(message("  ", "x").validate(), Err(PushError::TitleEmpty));
        assert_eq!(message("x", "").validate(), Err(PushError::BodyEmpty));
        assert_eq!(
            message(&"t".repeat(81), "x").validate(),
            Err(PushError::TitleTooLong)
        );
        assert_eq!(
            message("x", &"b".repeat(241)).validate(),
            Err(PushError::BodyTooLong)
        );
    }

    #[test]
    fn data_is_limited_and_cannot_use_reserved_keys() {
        let mut m = message("a", "b");
        m.data.insert("order_id".into(), "42".into());
        assert_eq!(m.validate(), Ok(()));
        for key in [
            "google.x",
            "gcm_y",
            "from",
            "message_type",
            "collapse_key",
            "has space",
            "",
            "dash-ed",
        ] {
            let mut bad = message("a", "b");
            bad.data.insert(key.into(), "v".into());
            assert_eq!(bad.validate(), Err(PushError::DataKeyInvalid), "{key:?}");
        }
        let mut long = message("a", "b");
        long.data.insert("k".into(), "v".repeat(201));
        assert_eq!(long.validate(), Err(PushError::DataValueTooLong));
        let mut many = message("a", "b");
        for i in 0..=DATA_MAX_KEYS {
            many.data.insert(format!("k{i}"), "v".into());
        }
        assert_eq!(many.validate(), Err(PushError::DataTooLarge));
    }

    #[test]
    fn bodies_reject_unknown_fields() {
        assert!(serde_json::from_str::<TokenRegistration>(
            r#"{"token":"a","platform":"ios","uid":"x"}"#
        )
        .is_err());
        assert!(
            serde_json::from_str::<TokenRegistration>(r#"{"token":"a","platform":"linux"}"#)
                .is_err()
        );
        assert!(serde_json::from_str::<TokenRemoval>(r#"{"token":"a","uid":"x"}"#).is_err());
        assert!(serde_json::from_str::<AdminSend>(
            r#"{"uid":"u","title":"t","body":"b","token":"x"}"#
        )
        .is_err());
    }

    #[test]
    fn admin_send_validates_uid_and_message() {
        let send = |uid: &str| AdminSend {
            uid: uid.into(),
            title: "t".into(),
            body: "b".into(),
            data: BTreeMap::new(),
        };
        assert_eq!(send("user-1").validate(), Ok(()));
        assert_eq!(send("").validate(), Err(PushError::UidInvalid));
        assert_eq!(
            send(&"u".repeat(129)).validate(),
            Err(PushError::UidInvalid)
        );
    }
}
