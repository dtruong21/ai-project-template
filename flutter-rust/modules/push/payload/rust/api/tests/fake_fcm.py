"""A fake Google (OAuth token endpoint + FCM send endpoint) for api_test.py.

The Worker is pointed at this instead of Google, so the push module can be
tested end to end without a Firebase project or a real key. It is strict about
what it accepts, so a mistake in how the Worker signs or sends fails here:

  * POST /token             verifies the Worker's signed JWT assertion
                            (RS256 signature, issuer, scope, audience, expiry)
                            before issuing an access token
  * POST .../messages:send  requires that access token; records each message.
                            A device token containing "dead" gets FCM's 404
                            UNREGISTERED, one containing "boom" gets a 500.
"""

from __future__ import annotations

import base64
import http.server
import json
import subprocess
import threading
import urllib.parse
from pathlib import Path

PROJECT = "test-project"
CLIENT_EMAIL = "push-test@test-project.iam.gserviceaccount.com"
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def _b64url_decode(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


class FakeGoogle:
    def __init__(self, workdir: Path):
        self.key = workdir / "fcm-sa-key.pem"
        self.pub = workdir / "fcm-sa-pub.pem"
        # `genpkey` writes PKCS#8, the format real service-account keys use.
        subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt",
                        "rsa_keygen_bits:2048", "-out", str(self.key)], check=True, capture_output=True)
        subprocess.run(["openssl", "pkey", "-in", str(self.key), "-pubout", "-out", str(self.pub)],
                       check=True, capture_output=True)
        self.workdir = workdir
        self.tokens_issued = 0
        self.valid_tokens: set[str] = set()
        self.messages: list[dict] = []
        self.rejected_assertions: list[str] = []
        self.lock = threading.Lock()

        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):  # quiet
                pass

            def _reply(self, status: int, body: dict) -> None:
                data = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                raw = self.rfile.read(length).decode()
                if self.path == "/token":
                    return self._token(raw)
                if self.path == f"/v1/projects/{PROJECT}/messages:send":
                    return self._send(raw)
                self._reply(404, {"error": {"status": "NOT_FOUND"}})

            def _token(self, raw: str) -> None:
                form = urllib.parse.parse_qs(raw)
                problem = fake.check_assertion(
                    form.get("grant_type", [""])[0], form.get("assertion", [""])[0], self.headers.get("Host", ""))
                if problem:
                    with fake.lock:
                        fake.rejected_assertions.append(problem)
                    return self._reply(400, {"error": "invalid_grant", "error_description": problem})
                with fake.lock:
                    fake.tokens_issued += 1
                    token = f"fake-access-{fake.tokens_issued}"
                    fake.valid_tokens.add(token)
                self._reply(200, {"access_token": token, "expires_in": 3600, "token_type": "Bearer"})

            def _send(self, raw: str) -> None:
                bearer = self.headers.get("Authorization", "").removeprefix("Bearer ")
                if bearer not in fake.valid_tokens:
                    return self._reply(401, {"error": {"status": "UNAUTHENTICATED"}})
                message = json.loads(raw)["message"]
                device = message["token"]
                if "dead" in device:
                    return self._reply(404, {"error": {"code": 404, "status": "NOT_FOUND",
                                                       "details": [{"errorCode": "UNREGISTERED"}]}})
                if "boom" in device:
                    return self._reply(500, {"error": {"status": "INTERNAL"}})
                with fake.lock:
                    fake.messages.append(message)
                self._reply(200, {"name": f"projects/{PROJECT}/messages/{len(fake.messages)}"})

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.port = self.server.server_address[1]
        self.base_url = f"http://127.0.0.1:{self.port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    # -- checks ---------------------------------------------------------------

    def check_assertion(self, grant_type: str, assertion: str, _host: str) -> str | None:
        """None if the JWT is exactly what Google would accept, else why not."""
        if grant_type != "urn:ietf:params:oauth:grant-type:jwt-bearer":
            return f"wrong grant_type {grant_type!r}"
        parts = assertion.split(".")
        if len(parts) != 3:
            return "assertion is not a JWT"
        try:
            header = json.loads(_b64url_decode(parts[0]))
            claims = json.loads(_b64url_decode(parts[1]))
            signature = _b64url_decode(parts[2])
        except ValueError:
            return "assertion is not valid base64/JSON"
        if header.get("alg") != "RS256":
            return f"alg is {header.get('alg')!r}, expected RS256"
        sig_file = self.workdir / "assertion.sig"
        sig_file.write_bytes(signature)
        verified = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(self.pub), "-signature", str(sig_file)],
            input=f"{parts[0]}.{parts[1]}".encode(), capture_output=True)
        if verified.returncode != 0:
            return "signature does not verify against the service account key"
        if claims.get("iss") != CLIENT_EMAIL:
            return f"iss is {claims.get('iss')!r}"
        if claims.get("scope") != SCOPE:
            return f"scope is {claims.get('scope')!r}"
        if claims.get("aud") != f"{self.base_url}/token":
            return f"aud is {claims.get('aud')!r}"
        if not (isinstance(claims.get("iat"), int) and isinstance(claims.get("exp"), int)
                and 0 < claims["exp"] - claims["iat"] <= 3600):
            return "iat/exp are not a window of at most one hour"
        return None

    # -- wiring ---------------------------------------------------------------

    def service_account_json(self) -> str:
        return json.dumps({
            "type": "service_account",
            "project_id": PROJECT,
            "client_email": CLIENT_EMAIL,
            "private_key": self.key.read_text(),
            "token_uri": f"{self.base_url}/token",
        })

    def worker_vars(self) -> list[str]:
        return [
            f"FCM_SERVICE_ACCOUNT:{self.service_account_json()}",
            f"FCM_BASE_URL:{self.base_url}",
            "PUSH_ADMIN_KEY:test-admin-key",
        ]

    def stop(self) -> None:
        self.server.shutdown()

    def messages_to(self, device_token: str) -> list[dict]:
        return [m for m in self.messages if m["token"] == device_token]
