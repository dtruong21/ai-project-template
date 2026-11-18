//! Payments module, app side: read the entitlements response.

use shared::payments::EntitlementList;

pub struct EntitlementItem {
    pub name: String,
    pub active: bool,
    /// Seconds since epoch, UTC. `None` = never expires.
    pub expires_at: Option<i64>,
    pub product: Option<String>,
}

/// Parses the body of `GET /v1/entitlements` (and `POST .../refresh`).
#[flutter_rust_bridge::frb(sync)]
pub fn parse_entitlements(json: String) -> Result<Vec<EntitlementItem>, String> {
    let list: EntitlementList =
        serde_json::from_str(&json).map_err(|_| "Unexpected response from the server.")?;
    Ok(list
        .entitlements
        .into_iter()
        .map(|e| EntitlementItem {
            name: e.name,
            active: e.active,
            expires_at: e.expires_at,
            product: e.product,
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_what_the_worker_sends() {
        let json = r#"{"entitlements":[
            {"name":"pro","active":true,"expires_at":1800000000,"product":"pro_monthly"},
            {"name":"lifetime","active":true,"expires_at":null,"product":null}]}"#;
        let items = parse_entitlements(json.to_string()).unwrap();
        assert_eq!(items.len(), 2);
        assert!(items[0].active && items[0].expires_at == Some(1_800_000_000));
        assert_eq!(items[1].expires_at, None);
    }

    #[test]
    fn a_bad_response_is_an_error_not_a_panic() {
        for bad in ["", "{}", "<html>", r#"{"entitlements":[{"name":1}]}"#] {
            assert!(parse_entitlements(bad.to_string()).is_err(), "{bad}");
        }
    }
}
