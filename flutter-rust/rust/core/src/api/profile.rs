//! Profile payloads. Same contract as `feedback.rs`: validate with the
//! shared rules, return the JSON body for Dart to send.

use shared::ProfileUpdate;

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
    fn invalid_name_never_produces_a_payload() {
        assert!(build_profile_payload("   ".to_string()).is_err());
        assert!(build_profile_payload("x".repeat(51)).is_err());
    }
}
