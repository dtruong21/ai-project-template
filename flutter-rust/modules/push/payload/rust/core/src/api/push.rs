//! Push module, app side: build the bodies for registering and removing this
//! device's token, validated with the same rules the Worker enforces.

use shared::push::{Platform, TokenRegistration, TokenRemoval};

/// JSON body for `PUT /v1/push/token`. `platform` may be Dart's
/// `defaultTargetPlatform.name`. The `Err` string is user-facing.
#[flutter_rust_bridge::frb(sync)]
pub fn build_push_token_payload(token: String, platform: String) -> Result<String, String> {
    let platform =
        Platform::parse(&platform).ok_or("This platform can't receive notifications.")?;
    let body = TokenRegistration { token, platform };
    body.validate().map_err(|e| e.to_string())?;
    serde_json::to_string(&body).map_err(|e| e.to_string())
}

/// JSON body for `DELETE /v1/push/token`.
#[flutter_rust_bridge::frb(sync)]
pub fn build_push_removal_payload(token: String) -> Result<String, String> {
    let body = TokenRemoval { token };
    body.validate().map_err(|e| e.to_string())?;
    serde_json::to_string(&body).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registration_body_is_what_the_worker_parses() {
        let json = build_push_token_payload("abc:123".into(), "iOS".into()).unwrap();
        let parsed: TokenRegistration = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.platform, Platform::Ios);
        assert_eq!(parsed.token, "abc:123");
    }

    #[test]
    fn bad_input_never_produces_a_body() {
        assert!(build_push_token_payload("has space".into(), "ios".into()).is_err());
        assert!(build_push_token_payload("abc".into(), "linux".into()).is_err());
        assert!(build_push_removal_payload("".into()).is_err());
        assert!(build_push_removal_payload("abc".into()).is_ok());
    }
}
