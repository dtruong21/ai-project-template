//! User profile — one row per Firebase uid.

use serde::{Deserialize, Serialize};

use crate::ValidationError;

pub const DISPLAY_NAME_MAX_CHARS: usize = 50;

/// Body of `PUT /v1/profile`. Creates the profile on first call, updates it
/// after. The uid comes from the token, never from here.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProfileUpdate {
    pub display_name: String,
}

impl ProfileUpdate {
    pub fn validate(&self) -> Result<(), ValidationError> {
        let name = self.display_name.trim();
        if name.is_empty() {
            return Err(ValidationError::DisplayNameEmpty);
        }
        if name.chars().count() > DISPLAY_NAME_MAX_CHARS {
            return Err(ValidationError::DisplayNameTooLong);
        }
        // Newlines, tabs and other control characters have no place in a name
        // shown in lists.
        if name.chars().any(char::is_control) {
            return Err(ValidationError::DisplayNameInvalid);
        }
        Ok(())
    }
}

/// What `GET /v1/profile` and `PUT /v1/profile` return.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Profile {
    pub display_name: String,
    pub created_at: i64,
    pub updated_at: i64,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn update(name: &str) -> ProfileUpdate {
        ProfileUpdate {
            display_name: name.to_string(),
        }
    }

    #[test]
    fn accepts_normal_names() {
        assert_eq!(update("David").validate(), Ok(()));
        assert_eq!(update("Đạt Trương").validate(), Ok(()));
    }

    #[test]
    fn rejects_blank() {
        assert_eq!(
            update("   ").validate(),
            Err(ValidationError::DisplayNameEmpty)
        );
    }

    #[test]
    fn limit_counts_characters_after_trimming() {
        let at_limit = format!("  {}  ", "é".repeat(DISPLAY_NAME_MAX_CHARS));
        assert_eq!(update(&at_limit).validate(), Ok(()));
        let over = "é".repeat(DISPLAY_NAME_MAX_CHARS + 1);
        assert_eq!(
            update(&over).validate(),
            Err(ValidationError::DisplayNameTooLong)
        );
    }

    #[test]
    fn rejects_control_characters() {
        assert_eq!(
            update("line\nbreak").validate(),
            Err(ValidationError::DisplayNameInvalid)
        );
    }

    #[test]
    fn rejects_unknown_json_fields() {
        let json = r#"{"display_name":"x","uid":"someone-else"}"#;
        assert!(serde_json::from_str::<ProfileUpdate>(json).is_err());
    }
}
