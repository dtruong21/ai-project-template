//! Firebase ID token verification.
//!
//! The app signs in with Firebase Auth and sends `Authorization: Bearer <ID
//! token>`. The token is a JWT signed by Google (RS256). We check, per
//! https://firebase.google.com/docs/auth/admin/verify-id-tokens :
//!   - signature, against Google's published keys (matched by `kid`)
//!   - `exp` not passed
//!   - `aud` == our Firebase project id
//!   - `iss` == https://securetoken.google.com/<project id>
//!   - `sub` (the uid) non-empty
//!
//! The returned uid is the ONLY identity a route may trust.

use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use worker::{Env, Fetch, Request, Url};

const JWKS_URL: &str =
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

#[derive(Deserialize)]
struct Jwks {
    keys: Vec<Jwk>,
}

#[derive(Deserialize)]
struct Jwk {
    kid: String,
    n: String,
    e: String,
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
}

/// Returns the verified Firebase uid, or a reason safe to send back as a 401.
pub async fn uid_from_request(req: &Request, env: &Env) -> Result<String, String> {
    let header = req
        .headers()
        .get("Authorization")
        .ok()
        .flatten()
        .ok_or("Missing Authorization header.")?;
    let token = header
        .strip_prefix("Bearer ")
        .ok_or("Authorization must be a Bearer token.")?;

    let project_id = env
        .var("FIREBASE_PROJECT_ID")
        .map(|v| v.to_string())
        .ok()
        .filter(|v| !v.is_empty())
        .ok_or("Server misconfigured: FIREBASE_PROJECT_ID is not set.")?;

    let kid = decode_header(token)
        .ok()
        .and_then(|h| h.kid)
        .ok_or("Malformed token.")?;

    // ponytail: fetches Google's keys on every request. They rotate rarely —
    // cache them (Cache API or KV, honoring the response's max-age) once
    // latency or request volume matters.
    let jwks = fetch_jwks()
        .await
        .map_err(|_| "Could not load token signing keys.")?;
    let jwk = jwks
        .keys
        .iter()
        .find(|k| k.kid == kid)
        .ok_or("Unknown token signing key.")?;
    let key =
        DecodingKey::from_rsa_components(&jwk.n, &jwk.e).map_err(|_| "Bad token signing key.")?;

    // Pinning RS256 here is what blocks `alg: none` / HS256 downgrade tricks.
    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[project_id.as_str()]);
    validation.set_issuer(&[format!("https://securetoken.google.com/{project_id}")]);

    let claims = decode::<Claims>(token, &key, &validation)
        .map_err(|_| "Invalid or expired token.")?
        .claims;

    if claims.sub.is_empty() {
        return Err("Token has no subject.".to_string());
    }
    Ok(claims.sub)
}

async fn fetch_jwks() -> worker::Result<Jwks> {
    let mut response = Fetch::Url(Url::parse(JWKS_URL)?).send().await?;
    response.json().await
}
