"""A fake RevenueCat REST API for api_test.py.

Only what the Worker uses:
  GET    /v1/subscribers/{app_user_id}   the user's current entitlements
  DELETE /v1/subscribers/{app_user_id}   erase the user

Strict where it matters: both need `Authorization: Bearer <secret key>`.
Tests set each user's state with `set()`; a user id containing "boom" gets a
500, to exercise the Worker's failure paths. Every call is recorded.
"""

from __future__ import annotations

import http.server
import json
import threading
import time
import urllib.parse

API_KEY = "sk_test_fake"
WEBHOOK_SECRET = "Bearer whsec_test_secret"


def iso(offset_seconds: int) -> str:
    """An RFC 3339 UTC timestamp `offset_seconds` from now (RevenueCat's format)."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + offset_seconds))


class FakeRevenueCat:
    def __init__(self):
        self.subscribers: dict[str, dict] = {}
        self.calls: list[tuple[str, str]] = []
        self.lock = threading.Lock()
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def _reply(self, status: int, body: dict) -> None:
                data = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def _handle(self, method: str) -> None:
                prefix = "/v1/subscribers/"
                if not self.path.startswith(prefix):
                    return self._reply(404, {"message": "not found"})
                uid = urllib.parse.unquote(self.path[len(prefix):])
                if self.headers.get("Authorization") != f"Bearer {API_KEY}":
                    return self._reply(401, {"message": "invalid api key"})
                with fake.lock:
                    fake.calls.append((method, uid))
                if "boom" in uid:
                    return self._reply(500, {"message": "internal"})
                if method == "DELETE":
                    fake.subscribers.pop(uid, None)
                    return self._reply(200, {})
                state = fake.subscribers.get(uid, {"entitlements": {}, "subscriptions": {}})
                self._reply(200, {"request_date_ms": int(time.time() * 1000),
                                  "subscriber": {"original_app_user_id": uid, **state}})

            def do_GET(self):
                self._handle("GET")

            def do_DELETE(self):
                self._handle("DELETE")

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.base_url = f"http://127.0.0.1:{self.server.server_address[1]}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def set(self, uid: str, entitlements: dict, subscriptions: dict | None = None) -> None:
        self.subscribers[uid] = {"entitlements": entitlements, "subscriptions": subscriptions or {}}

    def calls_for(self, method: str, uid: str) -> int:
        return sum(1 for m, u in self.calls if m == method and u == uid)

    def worker_vars(self) -> list[str]:
        return [
            f"REVENUECAT_API_KEY:{API_KEY}",
            f"REVENUECAT_BASE_URL:{self.base_url}",
            f"REVENUECAT_WEBHOOK_SECRET:{WEBHOOK_SECRET}",
        ]

    def stop(self) -> None:
        self.server.shutdown()
