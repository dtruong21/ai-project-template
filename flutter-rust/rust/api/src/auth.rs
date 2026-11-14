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

use std::cell::RefCell;
use std::rc::Rc;

use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use worker::{Date, Env, Fetch, Request, Url};

const GOOGLE_JWKS_URL: &str =
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

/// Google rotates these keys every few days and serves them with a max-age of
/// several hours. One hour keeps us well inside that and means one key fetch
/// per isolate per hour instead of one per request.
const JWKS_TTL_MS: u64 = 60 * 60 * 1000;

thread_local! {
    /// Per-isolate cache: `(fetched_at_ms, keys)`. Isolates are reused across
    /// requests, so this survives between them; a new isolate just refetches.
    static JWKS_CACHE: RefCell<Option<(u64, Rc<Jwks>)>> = const { RefCell::new(None) };
}

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

    // A `kid` we don't have cached may be a freshly rotated key: refetch once
    // before rejecting.
    let mut jwks = jwks(env, false)
        .await
        .map_err(|_| "Could not load token signing keys.")?;
    if !jwks.keys.iter().any(|k| k.kid == kid) {
        jwks = jwks_fresh(env)
            .await
            .map_err(|_| "Could not load token signing keys.")?;
    }
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
    validation.set_issuer(&[["https://securetoken.google.com/", project_id.as_str()].concat()]);

    let claims = decode::<Claims>(token, &key, &validation)
        .map_err(|_| "Invalid or expired token.")?
        .claims;

    if claims.sub.is_empty() {
        return Err("Token has no subject.".to_string());
    }
    Ok(claims.sub)
}

async fn jwks(env: &Env, force: bool) -> worker::Result<Rc<Jwks>> {
    let now = Date::now().as_millis();
    if !force {
        let cached = JWKS_CACHE.with(|cache| cache.borrow().clone());
        if let Some((fetched_at, keys)) = cached {
            if now.saturating_sub(fetched_at) < JWKS_TTL_MS {
                return Ok(keys);
            }
        }
    }
    let mut response = Fetch::Url(Url::parse(&jwks_url(env))?).send().await?;
    let keys: Rc<Jwks> = Rc::new(response.json().await?);
    JWKS_CACHE.with(|cache| *cache.borrow_mut() = Some((now, keys.clone())));
    Ok(keys)
}

async fn jwks_fresh(env: &Env) -> worker::Result<Rc<Jwks>> {
    jwks(env, true).await
}

/// Google's key set, unless `FIREBASE_JWKS_URL` overrides it.
///
/// SECURITY: whoever controls this URL can mint tokens for any user. The
/// override exists only so `tests/api_test.sh` can sign its own test tokens.
/// Never set it in `wrangler.toml` or as a deployed variable.
fn jwks_url(env: &Env) -> String {
    env.var("FIREBASE_JWKS_URL")
        .map(|v| v.to_string())
        .ok()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| GOOGLE_JWKS_URL.to_string())
}
