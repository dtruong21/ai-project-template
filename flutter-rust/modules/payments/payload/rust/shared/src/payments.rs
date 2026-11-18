//! Payments module (RevenueCat) — rules shared by the app and the Worker.
//!
//! The model: the stores sell, RevenueCat validates the receipt, and the
//! Worker keeps one row per (user, entitlement). "Is this user paid?" is
//! answered by the Worker from those rows — never by the app's say-so.

use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

pub const NAME_MAX_CHARS: usize = 64;
pub const UID_MAX_CHARS: usize = 128;

/// Error `code`s this module adds to the API's error envelope.
pub const PAYMENT_REQUIRED: &str = "payment_required";
pub const NOT_CONFIGURED: &str = "payments_not_configured";
pub const UPSTREAM_UNAVAILABLE: &str = "payments_upstream_unavailable";

/// RevenueCat ids for users who have not logged in. They are never ours.
const ANONYMOUS_PREFIX: &str = "$RCAnonymousID:";

// ── what the app sees ────────────────────────────────────────────────────────

/// One entitlement as returned by `GET /v1/entitlements`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntitlementView {
    pub name: String,
    /// Computed from `expires_at` at read time, so expiry takes effect even
    /// if the webhook announcing it is late or lost.
    pub active: bool,
    /// Seconds since epoch, UTC. `None` = never expires (lifetime unlock).
    pub expires_at: Option<i64>,
    pub product: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntitlementList {
    pub entitlements: Vec<EntitlementView>,
}

/// `None` never expires; otherwise active while `now < expires_at`.
pub fn is_active(expires_at: Option<i64>, now: i64) -> bool {
    expires_at.is_none_or(|at| now < at)
}

// ── RevenueCat webhook ───────────────────────────────────────────────────────

/// What we read from a webhook. Deliberately lenient (RevenueCat adds fields
/// over time) and deliberately thin: we never trust the event's *content* —
/// it only tells us whose state changed, and we then ask RevenueCat for the
/// authoritative answer. That makes duplicate, late and out-of-order events
/// harmless.
#[derive(Debug, Clone, Deserialize)]
pub struct WebhookEnvelope {
    pub event: WebhookEvent,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WebhookEvent {
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub app_user_id: Option<String>,
    #[serde(default)]
    pub transferred_from: Option<Vec<String>>,
    #[serde(default)]
    pub transferred_to: Option<Vec<String>>,
}

fn usable_user_id(id: &str) -> bool {
    !id.is_empty()
        && id.chars().count() <= UID_MAX_CHARS
        && !id.starts_with(ANONYMOUS_PREFIX)
        && !id.chars().any(char::is_control)
}

impl WebhookEvent {
    /// Users whose entitlements must be re-read. Empty for `TEST` events and
    /// for anonymous or malformed ids.
    pub fn users_to_refresh(&self) -> Vec<String> {
        if self.kind == "TEST" {
            return Vec::new();
        }
        let mut ids: BTreeSet<String> = BTreeSet::new();
        if self.kind == "TRANSFER" {
            // Entitlements moved between users: both sides changed.
            for id in self
                .transferred_from
                .iter()
                .chain(&self.transferred_to)
                .flatten()
            {
                ids.insert(id.clone());
            }
        } else if let Some(id) = &self.app_user_id {
            ids.insert(id.clone());
        }
        ids.into_iter().filter(|id| usable_user_id(id)).collect()
    }
}

// ── RevenueCat REST: GET /v1/subscribers/{id} ────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct SubscriberResponse {
    pub subscriber: Subscriber,
}

#[derive(Debug, Deserialize)]
pub struct Subscriber {
    #[serde(default)]
    pub entitlements: BTreeMap<String, RcEntitlement>,
    #[serde(default)]
    pub subscriptions: BTreeMap<String, RcSubscription>,
}

#[derive(Debug, Deserialize)]
pub struct RcEntitlement {
    #[serde(default)]
    pub expires_date: Option<String>,
    #[serde(default)]
    pub grace_period_expires_date: Option<String>,
    #[serde(default)]
    pub product_identifier: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RcSubscription {
    #[serde(default)]
    pub store: Option<String>,
}

/// What we store for one entitlement.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EntitlementRow {
    pub name: String,
    pub expires_at: Option<i64>,
    pub product: Option<String>,
    pub store: Option<String>,
}

impl Subscriber {
    /// Rows to store. Includes entitlements that already expired (history is
    /// harmless; `active` is computed at read time). A date we cannot parse
    /// is treated as already expired — never as "forever".
    pub fn entitlement_rows(&self) -> Vec<EntitlementRow> {
        self.entitlements
            .iter()
            .filter(|(name, _)| {
                !name.is_empty()
                    && name.chars().count() <= NAME_MAX_CHARS
                    && name
                        .chars()
                        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | '.'))
            })
            .map(|(name, ent)| {
                let expires = ent
                    .expires_date
                    .as_deref()
                    .map(|d| parse_iso8601_utc(d).unwrap_or(0));
                let grace = ent
                    .grace_period_expires_date
                    .as_deref()
                    .map(|d| parse_iso8601_utc(d).unwrap_or(0));
                // A billing-retry grace period keeps access past the nominal end.
                let expires_at = match (expires, grace) {
                    (None, _) => None, // lifetime
                    (Some(e), Some(g)) => Some(e.max(g)),
                    (Some(e), None) => Some(e),
                };
                let product = ent.product_identifier.clone();
                let store = product
                    .as_ref()
                    .and_then(|p| self.subscriptions.get(p))
                    .and_then(|s| s.store.clone());
                EntitlementRow {
                    name: name.clone(),
                    expires_at,
                    product,
                    store,
                }
            })
            .collect()
    }
}

/// `2026-12-01T10:20:30Z` (optionally with fractional seconds) → seconds
/// since the Unix epoch. `None` for anything else.
pub fn parse_iso8601_utc(text: &str) -> Option<i64> {
    let text = text.strip_suffix('Z')?;
    let (date, time) = text.split_once('T')?;
    let mut d = date.split('-');
    let (year, month, day): (i64, i64, i64) = (
        d.next()?.parse().ok()?,
        d.next()?.parse().ok()?,
        d.next()?.parse().ok()?,
    );
    if d.next().is_some() || !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    let time = time.split('.').next()?;
    let mut t = time.split(':');
    let (h, m, s): (i64, i64, i64) = (
        t.next()?.parse().ok()?,
        t.next()?.parse().ok()?,
        t.next()?.parse().ok()?,
    );
    if t.next().is_some() || !(0..24).contains(&h) || !(0..60).contains(&m) || !(0..61).contains(&s)
    {
        return None;
    }
    // days-from-civil (Howard Hinnant): proleptic Gregorian → days since 1970-01-01.
    let y = if month <= 2 { year - 1 } else { year };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146_097 + doe - 719_468;
    Some(days * 86_400 + h * 3600 + m * 60 + s)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_iso_dates() {
        assert_eq!(parse_iso8601_utc("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_iso8601_utc("2000-03-01T00:00:00Z"), Some(951_868_800));
        assert_eq!(
            parse_iso8601_utc("2026-11-18T12:34:56Z"),
            Some(1_795_005_296)
        );
        assert_eq!(
            parse_iso8601_utc("2024-02-29T23:59:59.999Z"),
            Some(1_709_251_199)
        ); // leap day, fraction ignored
        assert_eq!(parse_iso8601_utc("1969-12-31T23:59:59Z"), Some(-1));
    }

    #[test]
    fn rejects_malformed_dates() {
        for bad in [
            "",
            "tomorrow",
            "2026-11-18",
            "2026-11-18T12:00:00",
            "2026-13-01T00:00:00Z",
            "2026-11-18T25:00:00Z",
            "2026-11-18T12:00Z",
            "2026-11-18T12:00:00+01:00",
        ] {
            assert_eq!(parse_iso8601_utc(bad), None, "{bad:?}");
        }
    }

    #[test]
    fn activity_is_computed_from_expiry() {
        assert!(is_active(None, 1_000_000)); // lifetime
        assert!(is_active(Some(2_000), 1_999));
        assert!(!is_active(Some(2_000), 2_000));
        assert!(!is_active(Some(0), 1));
    }

    fn event(json: &str) -> WebhookEvent {
        serde_json::from_str::<WebhookEnvelope>(json).unwrap().event
    }

    #[test]
    fn webhook_names_the_user_to_refresh() {
        assert_eq!(
            event(r#"{"api_version":"1.0","event":{"type":"RENEWAL","app_user_id":"uid-1","extra":{"a":1}}}"#).users_to_refresh(),
            vec!["uid-1"]
        );
    }

    #[test]
    fn webhook_ignores_tests_anonymous_and_bad_ids() {
        assert!(event(r#"{"event":{"type":"TEST","app_user_id":"uid-1"}}"#)
            .users_to_refresh()
            .is_empty());
        assert!(
            event(r#"{"event":{"type":"RENEWAL","app_user_id":"$RCAnonymousID:abc"}}"#)
                .users_to_refresh()
                .is_empty()
        );
        assert!(event(r#"{"event":{"type":"RENEWAL"}}"#)
            .users_to_refresh()
            .is_empty());
        assert!(event(r#"{"event":{"type":"RENEWAL","app_user_id":""}}"#)
            .users_to_refresh()
            .is_empty());
        let long = format!(
            r#"{{"event":{{"type":"RENEWAL","app_user_id":"{}"}}}}"#,
            "u".repeat(200)
        );
        assert!(event(&long).users_to_refresh().is_empty());
        assert!(
            event("{\"event\":{\"type\":\"RENEWAL\",\"app_user_id\":\"a\\nb\"}}")
                .users_to_refresh()
                .is_empty()
        );
    }

    #[test]
    fn transfer_refreshes_both_sides_once() {
        let e = event(
            r#"{"event":{"type":"TRANSFER","transferred_from":["a","$RCAnonymousID:x"],"transferred_to":["b","a"]}}"#,
        );
        assert_eq!(e.users_to_refresh(), vec!["a", "b"]);
    }

    #[test]
    fn webhook_without_an_event_is_rejected() {
        assert!(serde_json::from_str::<WebhookEnvelope>("{}").is_err());
        assert!(serde_json::from_str::<WebhookEnvelope>("nope").is_err());
    }

    fn rows(json: &str) -> Vec<EntitlementRow> {
        serde_json::from_str::<SubscriberResponse>(json)
            .unwrap()
            .subscriber
            .entitlement_rows()
    }

    #[test]
    fn subscriber_becomes_rows() {
        let r = rows(
            r#"{"subscriber":{
            "entitlements":{"pro":{"expires_date":"2026-12-01T00:00:00Z","product_identifier":"pro_monthly"}},
            "subscriptions":{"pro_monthly":{"store":"app_store"}}}}"#,
        );
        assert_eq!(
            r,
            vec![EntitlementRow {
                name: "pro".into(),
                expires_at: Some(parse_iso8601_utc("2026-12-01T00:00:00Z").unwrap()),
                product: Some("pro_monthly".into()),
                store: Some("app_store".into()),
            }]
        );
    }

    #[test]
    fn lifetime_has_no_expiry() {
        let r = rows(
            r#"{"subscriber":{"entitlements":{"lifetime":{"expires_date":null,"product_identifier":"unlock"}}}}"#,
        );
        assert_eq!(r[0].expires_at, None);
    }

    #[test]
    fn grace_period_extends_access() {
        let r = rows(
            r#"{"subscriber":{"entitlements":{"pro":{"expires_date":"2026-12-01T00:00:00Z","grace_period_expires_date":"2026-12-17T00:00:00Z"}}}}"#,
        );
        assert_eq!(r[0].expires_at, parse_iso8601_utc("2026-12-17T00:00:00Z"));
    }

    #[test]
    fn an_unreadable_date_means_expired_never_forever() {
        let r = rows(r#"{"subscriber":{"entitlements":{"pro":{"expires_date":"garbage"}}}}"#);
        assert_eq!(r[0].expires_at, Some(0));
        assert!(!is_active(r[0].expires_at, 1));
    }

    #[test]
    fn odd_entitlement_names_are_dropped_and_empty_is_fine() {
        let r = rows(
            r#"{"subscriber":{"entitlements":{"has space":{},"ok_name":{"expires_date":null}}}}"#,
        );
        assert_eq!(
            r.iter().map(|e| e.name.as_str()).collect::<Vec<_>>(),
            vec!["ok_name"]
        );
        assert!(rows(r#"{"subscriber":{}}"#).is_empty());
    }
}
