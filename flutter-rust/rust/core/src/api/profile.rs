//! Profile payloads. Same contract as `feedback.rs`: validate with the
//! shared rules, return the JSON body for Dart to send.

use shared::{Profile, ProfileUpdate};

/// Validates a display name and returns the JSON body for `PUT /v1/profile`.
/// The `Err` string is user-facing.
#[flutter_rust_bridge::frb(sync)]
pub fn build_profile_payload(display_name: String) -> Result<String, String> {
    let update = ProfileUpdate {
        display_name: display_name.trim().to_string(),
    };
    update.validate().map_err(|e| e.to_string())?;
    serde_json::to_string(&update).map_err(|e| e.to_string())
}

pub struct ProfileView {
    pub display_name: String,
    /// Seconds since epoch, UTC.
    pub created_at: i64,
    pub updated_at: i64,
}

/// Parses the body of `GET` / `PUT /v1/profile`.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_profile(json: String) -> Result<ProfileView, String> {
    let profile: Profile =
        serde_json::from_str(&json).map_err(|_| "Unexpected response from the server.")?;
    Ok(ProfileView {
        display_name: profile.display_name,
        created_at: profile.created_at,
        updated_at: profile.updated_at,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn payload_is_what_the_worker_parses() {
        let json = build_profile_payload("  Alice  ".to_string()).unwrap();
        let parsed: ProfileUpdate = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.display_name, "Alice");
    }

    #[test]
    fn parses_a_profile_from_the_worker() {
        let json = r#"{"display_name":"Alice","created_at":1700000000,"updated_at":1700000100}"#;
        let profile = parse_profile(json.to_string()).unwrap();
        assert_eq!(profile.display_name, "Alice");
        assert_eq!(profile.updated_at, 1_700_000_100);
        assert!(parse_profile("{}".to_string()).is_err());
    }

    #[test]
    fn invalid_name_never_produces_a_payload() {
        assert!(build_profile_payload("   ".to_string()).is_err());
        assert!(build_profile_payload("x".repeat(51)).is_err());
    }
}
