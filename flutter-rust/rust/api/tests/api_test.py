#!/usr/bin/env python3
"""End-to-end test of the Worker API against a local Worker + local D1.

    cd rust/api && python3 tests/api_test.py

What it does:
  1. Generates a throwaway RSA key and serves its public half as a JWKS file
     on localhost.
  2. Starts `wrangler dev` with a fresh, temporary database and
     FIREBASE_JWKS_URL pointing at that file, so tokens signed here verify
     exactly like real Firebase ID tokens do.
  3. Calls every route as two different users plus a set of forged tokens,
     and checks status codes, error codes, and that users never see or touch
     each other's rows.

Needs: python3 (stdlib only), openssl, node/npx, and the Rust wasm toolchain
that `wrangler dev` already requires. Touches nothing outside a temp dir.

Add a block here whenever you add a route — at minimum: no token → 401, and
user B cannot read/change user A's row.
"""

from __future__ import annotations

import base64
import http.server
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_DIR = Path(__file__).resolve().parent.parent
PROJECT_ID = "api-test-project"
ISSUER = f"https://securetoken.google.com/{PROJECT_ID}"
API_PORT = int(os.environ.get("API_TEST_PORT", "8791"))
JWKS_PORT = int(os.environ.get("API_TEST_JWKS_PORT", "8792"))
BASE = f"http://127.0.0.1:{API_PORT}"
FAR_FUTURE = 4102444800  # 2100-01-01

# Where the temporary D1 / R2 state lives; set by main(). Lets a test look at
# storage directly (e.g. that account deletion really removed stored bytes).
STATE_DIR: Path | None = None

failures: list[str] = []
passed = 0


# ── tokens ───────────────────────────────────────────────────────────────────


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


class Signer:
    def __init__(self, workdir: Path):
        self.key = workdir / "test-key.pem"
        subprocess.run(
            ["openssl", "genrsa", "-out", str(self.key), "2048"],
            check=True,
            capture_output=True,
        )
        modulus = subprocess.run(
            ["openssl", "rsa", "-in", str(self.key), "-noout", "-modulus"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip().split("=", 1)[1]
        jwks = {
            "keys": [
                {
                    "kty": "RSA",
                    "alg": "RS256",
                    "use": "sig",
                    "kid": "test-kid",
                    "n": b64url(bytes.fromhex(modulus)),
                    "e": "AQAB",
                }
            ]
        }
        (workdir / "jwks.json").write_text(json.dumps(jwks))

    def token(self, claims: dict, *, kid: str = "test-kid", alg: str = "RS256") -> str:
        header = b64url(json.dumps({"alg": alg, "typ": "JWT", "kid": kid}).encode())
        payload = b64url(json.dumps(claims).encode())
        if alg == "none":
            return f"{header}.{payload}."
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", str(self.key)],
            input=f"{header}.{payload}".encode(),
            check=True,
            capture_output=True,
        ).stdout
        return f"{header}.{payload}.{b64url(signature)}"

    def user(self, uid: str) -> str:
        return self.token(
            {"sub": uid, "aud": PROJECT_ID, "iss": ISSUER, "exp": FAR_FUTURE, "iat": 1}
        )


# ── http ─────────────────────────────────────────────────────────────────────


def call(method: str, path: str, token: str | None = None, body=None, raw: bytes | None = None):
    """Returns (status, parsed JSON or raw text)."""
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(BASE + path, data=data, method=method)
    if token is not None:
        request.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status, text = response.status, response.read().decode(errors="replace")
    except urllib.error.HTTPError as error:
        status, text = error.code, error.read().decode(errors="replace")
    try:
        return status, json.loads(text)
    except ValueError:
        return status, text


def check(name: str, condition: bool, detail: object = "") -> None:
    global passed
    if condition:
        passed += 1
    else:
        failures.append(f"{name}  →  {detail}")
        print(f"  FAIL  {name}  →  {detail}")


def expect(name: str, response, status: int, code: str | None = None) -> None:
    got_status, body = response
    got_code = body.get("error", {}).get("code") if isinstance(body, dict) else None
    ok = got_status == status and (code is None or got_code == code)
    check(name, ok, f"expected {status} {code or ''}, got {got_status} {body!r}"[:300])


# ── the tests ────────────────────────────────────────────────────────────────


def run_tests(signer: Signer) -> None:
    alice, bob = signer.user("user-alice"), signer.user("user-bob")
    feedback = {
        "category": "idea",
        "body": "dark mode please",
        "route": "/home",
        "app_version": "1.0.0",
        "platform": "test",
    }

    print("routing")
    status, body = call("GET", "/health")
    check("health is public", status == 200 and body == "ok", (status, body))
    expect("unknown route is a JSON 404", call("GET", "/nope"), 404, "not_found")
    expect("unknown /v1 route is a JSON 404", call("GET", "/v1/nope", alice), 404, "not_found")

    print("authentication — every /v1 route rejects a missing token")
    for method, path in [
        ("POST", "/v1/feedback"),
        ("GET", "/v1/feedback"),
        ("DELETE", "/v1/feedback/abc"),
        ("GET", "/v1/profile"),
        ("PUT", "/v1/profile"),
        ("DELETE", "/v1/account"),
    ]:
        expect(f"no token: {method} {path}", call(method, path, body={}), 401, "unauthenticated")

    print("authentication — forged tokens")
    good_claims = {"sub": "user-alice", "aud": PROJECT_ID, "iss": ISSUER, "exp": FAR_FUTURE}
    head, _, signature = alice.split(".")
    tampered_payload = b64url(json.dumps({**good_claims, "sub": "user-bob"}).encode())
    forged = {
        "garbage": "not.a.jwt",
        "empty": "",
        "alg none": signer.token(good_claims, alg="none"),
        "unknown key id": signer.token(good_claims, kid="some-other-key"),
        "expired": signer.token({**good_claims, "exp": 1000}),
        "no expiry": signer.token({k: v for k, v in good_claims.items() if k != "exp"}),
        "wrong audience": signer.token({**good_claims, "aud": "another-project"}),
        "wrong issuer": signer.token({**good_claims, "iss": "https://evil.example/" + PROJECT_ID}),
        "empty subject": signer.token({**good_claims, "sub": ""}),
        "tampered payload": f"{head}.{tampered_payload}.{signature}",
    }
    for name, token in forged.items():
        expect(f"forged token ({name})", call("GET", "/v1/feedback", token), 401, "unauthenticated")

    print("feedback — create")
    for i in range(3):
        expect(
            f"create #{i + 1}",
            call("POST", "/v1/feedback", alice, {**feedback, "body": f"message {i + 1}"}),
            201,
        )
        time.sleep(1.1)  # distinct created_at seconds → deterministic order
    expect(
        "blank body",
        call("POST", "/v1/feedback", alice, {**feedback, "body": "   "}),
        422,
        "validation_failed",
    )
    expect(
        "body too long",
        call("POST", "/v1/feedback", alice, {**feedback, "body": "x" * 2001}),
        422,
        "validation_failed",
    )
    expect(
        "smuggled uid field",
        call("POST", "/v1/feedback", alice, {**feedback, "uid": "user-bob"}),
        400,
        "invalid_body",
    )
    expect(
        "unknown category",
        call("POST", "/v1/feedback", alice, {**feedback, "category": "spam"}),
        400,
        "invalid_body",
    )
    expect("not JSON", call("POST", "/v1/feedback", alice, raw=b"hello"), 400, "invalid_body")
    expect("empty request body", call("POST", "/v1/feedback", alice, raw=b""), 400, "invalid_body")
    injection = "x'); DROP TABLE feedback;--"
    expect(
        "SQL text in body is stored as text",
        call("POST", "/v1/feedback", bob, {**feedback, "body": injection}),
        201,
    )

    print("feedback — list and paging")
    status, page1 = call("GET", "/v1/feedback?limit=2", alice)
    items1 = page1.get("items", []) if isinstance(page1, dict) else []
    check("page 1 has 2 items", status == 200 and len(items1) == 2, page1)
    check("newest first", [i["body"] for i in items1] == ["message 3", "message 2"], items1)
    check("rows carry no uid", all("uid" not in i for i in items1), items1)
    cursor = page1.get("next_cursor") if isinstance(page1, dict) else None
    check("page 1 has a next cursor", bool(cursor), page1)
    status, page2 = call("GET", f"/v1/feedback?limit=2&cursor={cursor}", alice)
    items2 = page2.get("items", []) if isinstance(page2, dict) else []
    check("page 2 has the remaining item", [i["body"] for i in items2] == ["message 1"], page2)
    check("last page has no cursor", isinstance(page2, dict) and page2.get("next_cursor") is None, page2)
    expect("bad cursor", call("GET", "/v1/feedback?cursor=abc", alice), 400, "invalid_query")
    expect(
        "SQL in cursor",
        call("GET", "/v1/feedback?cursor=1_ab%27%3B%20DROP%20TABLE%20feedback%3B--", alice),
        400,
        "invalid_query",
    )
    status, big = call("GET", "/v1/feedback?limit=99999", alice)
    check("huge limit is clamped, not an error", status == 200 and len(big["items"]) == 3, big)
    status, zero = call("GET", "/v1/feedback?limit=0", alice)
    check("limit=0 still returns a row", status == 200 and len(zero["items"]) == 1, zero)

    print("feedback — isolation between users")
    status, bobs = call("GET", "/v1/feedback", bob)
    bob_items = bobs.get("items", []) if isinstance(bobs, dict) else []
    check("bob sees only his own row", [i["body"] for i in bob_items] == [injection], bobs)
    check("table survived the injection text", status == 200, bobs)
    alice_id = items1[0]["id"] if items1 else "missing"
    expect("bob cannot delete alice's row", call("DELETE", f"/v1/feedback/{alice_id}", bob), 404, "not_found")
    status, still = call("GET", "/v1/feedback", alice)
    check("alice's row is still there", len(still.get("items", [])) == 3, still)
    expect("alice deletes her row", call("DELETE", f"/v1/feedback/{alice_id}", alice), 204)
    expect("deleting it again is a 404", call("DELETE", f"/v1/feedback/{alice_id}", alice), 404, "not_found")
    expect("deleting a made-up id is a 404", call("DELETE", "/v1/feedback/doesnotexist", alice), 404, "not_found")

    print("profile")
    expect("no profile yet", call("GET", "/v1/profile", alice), 404, "not_found")
    status, created = call("PUT", "/v1/profile", alice, {"display_name": "  Alice  "})
    check("create profile, name trimmed", status == 200 and created.get("display_name") == "Alice", created)
    time.sleep(1.1)
    status, updated = call("PUT", "/v1/profile", alice, {"display_name": "Alice B"})
    check(
        "update keeps created_at, bumps updated_at",
        status == 200
        and updated.get("display_name") == "Alice B"
        and updated.get("created_at") == created.get("created_at")
        and updated.get("updated_at", 0) > created.get("updated_at", 0),
        (created, updated),
    )
    status, fetched = call("GET", "/v1/profile", alice)
    check("get returns the profile", status == 200 and fetched == updated, fetched)
    expect("blank name", call("PUT", "/v1/profile", alice, {"display_name": " "}), 422, "validation_failed")
    expect("name too long", call("PUT", "/v1/profile", alice, {"display_name": "x" * 51}), 422, "validation_failed")
    expect(
        "smuggled uid field",
        call("PUT", "/v1/profile", alice, {"display_name": "x", "uid": "user-bob"}),
        400,
        "invalid_body",
    )
    expect("bob has no profile (cannot see alice's)", call("GET", "/v1/profile", bob), 404, "not_found")

    # modules: tests

    print("account deletion")
    call("PUT", "/v1/profile", bob, {"display_name": "Bob"})
    expect("alice deletes her account", call("DELETE", "/v1/account", alice), 204)
    status, after = call("GET", "/v1/feedback", alice)
    check("alice's feedback is gone", status == 200 and after.get("items") == [], after)
    expect("alice's profile is gone", call("GET", "/v1/profile", alice), 404, "not_found")
    expect("deleting again still succeeds", call("DELETE", "/v1/account", alice), 204)
    status, bobs_after = call("GET", "/v1/feedback", bob)
    check("bob's feedback is untouched", len(bobs_after.get("items", [])) == 1, bobs_after)
    status, bob_profile = call("GET", "/v1/profile", bob)
    check("bob's profile is untouched", status == 200 and bob_profile.get("display_name") == "Bob", bob_profile)


# ── harness ──────────────────────────────────────────────────────────────────


def serve_jwks(workdir: Path) -> http.server.ThreadingHTTPServer:
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(workdir), **kwargs)

        def log_message(self, *args):  # quiet
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", JWKS_PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def wait_for_api(process: subprocess.Popen, log: Path, timeout: int = 600) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if process.poll() is not None:
            sys.exit(f"wrangler dev exited early. Log:\n{log.read_text()[-3000:]}")
        try:
            with urllib.request.urlopen(BASE + "/health", timeout=2) as response:
                if response.status == 200:
                    return
        except OSError:
            time.sleep(1)
    sys.exit(f"API did not start within {timeout}s. Log:\n{log.read_text()[-3000:]}")


def main() -> int:
    for tool in ("openssl", "npx"):
        if shutil.which(tool) is None:
            sys.exit(f"missing required tool: {tool}")

    workdir = Path(tempfile.mkdtemp(prefix="api-test-"))
    state = workdir / "state"
    global STATE_DIR
    STATE_DIR = state
    log = workdir / "wrangler.log"
    env = {**os.environ, "WRANGLER_SEND_METRICS": "false", "CI": "1"}
    process = None
    server = None
    try:
        signer = Signer(workdir)
        server = serve_jwks(workdir)

        print("applying migrations to a fresh local database…")
        subprocess.run(
            ["npx", "--yes", "wrangler", "d1", "migrations", "apply", "DB", "--local",
             "--persist-to", str(state)],
            cwd=API_DIR, env=env, check=True, capture_output=True,
        )

        print("starting the Worker (first run compiles Rust — can take minutes)…")
        with log.open("w") as log_file:
            process = subprocess.Popen(
                ["npx", "wrangler", "dev", "--port", str(API_PORT), "--ip", "127.0.0.1",
                 "--persist-to", str(state),
                 "--var", f"FIREBASE_PROJECT_ID:{PROJECT_ID}",
                 "--var", f"FIREBASE_JWKS_URL:http://127.0.0.1:{JWKS_PORT}/jwks.json"],
                cwd=API_DIR, env=env, stdout=log_file, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        wait_for_api(process, log)

        run_tests(signer)
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
        if server is not None:
            server.shutdown()
        if failures and log.exists():
            print(f"\n--- wrangler log (tail) ---\n{log.read_text()[-2000:]}")
        shutil.rmtree(workdir, ignore_errors=True)

    print(f"\n{passed} passed, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
