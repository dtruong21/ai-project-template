    print("payments module")
    rc = MODULE_STATE["rc"]
    iso = MODULE_STATE["rc_module"].iso
    WEBHOOK_AUTH = MODULE_STATE["rc_module"].WEBHOOK_SECRET
    ivy, jo, kim, lee, mia, nia = (signer.user(f"user-{n}") for n in ("ivy", "jo", "kim", "lee", "mia", "nia"))

    def webhook(event, secret=WEBHOOK_AUTH, raw=None):
        data = raw if raw is not None else json.dumps({"api_version": "1.0", "event": event}).encode()
        request = urllib.request.Request(BASE + "/v1/webhooks/revenuecat", data=data, method="POST")
        request.add_header("Content-Type", "application/json")
        if secret is not None:
            request.add_header("Authorization", secret)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, json.loads(response.read().decode())
        except urllib.error.HTTPError as error:
            text = error.read().decode(errors="replace")
            try:
                return error.code, json.loads(text)
            except ValueError:
                return error.code, text

    def entitlements(token):
        status, body = call("GET", "/v1/entitlements", token)
        return {e["name"]: e for e in body["entitlements"]} if status == 200 else {"_status": status}

    for method, path in [("GET", "/v1/entitlements"), ("POST", "/v1/entitlements/refresh"), ("GET", "/v1/pro/ping")]:
        expect(f"payments: no token: {method} {path}", call(method, path, body={}), 401, "unauthenticated")

    check("a new user has no entitlements", entitlements(ivy) == {}, entitlements(ivy))
    expect("...so a gated route says payment required", call("GET", "/v1/pro/ping", ivy), 402, "payment_required")

    print("payments module — webhook credentials")
    event = {"type": "INITIAL_PURCHASE", "app_user_id": "user-ivy"}
    calls_before = len(rc.calls)  # earlier modules' account deletions also call RevenueCat
    expect("webhook: no credentials", webhook(event, secret=None), 401, "unauthenticated")
    expect("webhook: wrong secret", webhook(event, secret="Bearer nope"), 401, "unauthenticated")
    expect("webhook: a user's ID token is not the secret", webhook(event, secret=f"Bearer {ivy}"), 401, "unauthenticated")
    check("rejected webhooks did not reach RevenueCat", rc.calls[calls_before:] == [], rc.calls[calls_before:])
    expect("webhook: not JSON", webhook(None, raw=b"nope"), 400, "invalid_body")
    expect("webhook: no event", webhook(None, raw=b"{}"), 400, "invalid_body")

    print("payments module — a purchase")
    rc.set("user-ivy", {"pro": {"expires_date": iso(3600), "product_identifier": "pro_monthly"}},
           {"pro_monthly": {"store": "app_store"}})
    status, body = webhook(event)
    check("webhook accepted", status == 200 and body == {"refreshed": 1}, (status, body))
    ent = entitlements(ivy).get("pro", {})
    check("the entitlement is active with its expiry and product", ent.get("active") is True
          and abs(ent.get("expires_at", 0) - (time.time() + 3600)) < 30 and ent.get("product") == "pro_monthly", ent)
    expect("a gated route now works", call("GET", "/v1/pro/ping", ivy), 200)
    check("another user is not affected", entitlements(jo) == {}, entitlements(jo))
    expect("...and is still refused", call("GET", "/v1/pro/ping", jo), 402, "payment_required")

    print("payments module — the app cannot grant itself anything")
    for method in ("POST", "PUT", "PATCH", "DELETE"):
        status, _ = call(method, "/v1/entitlements", jo, {"name": "pro", "active": True})
        check(f"{method} /v1/entitlements is not a route", status in (404, 405), status)
    check("jo is still unpaid", entitlements(jo) == {}, entitlements(jo))

    print("payments module — ignored events")
    before = len(rc.calls)
    check("anonymous RevenueCat id is ignored", webhook({"type": "RENEWAL", "app_user_id": "$RCAnonymousID:abc"}) == (200, {"refreshed": 0}), "")
    check("TEST event is ignored", webhook({"type": "TEST", "app_user_id": "user-ivy"}) == (200, {"refreshed": 0}), "")
    check("ignored events never called RevenueCat", len(rc.calls) == before, rc.calls[before:])

    print("payments module — the event is a nudge; RevenueCat is the truth")
    rc.set("user-ivy", {"pro": {"expires_date": iso(-60), "product_identifier": "pro_monthly"}})
    webhook({"type": "INITIAL_PURCHASE", "app_user_id": "user-ivy"})  # a stale event claiming a purchase
    check("a stale 'purchase' event cannot revive an expired entitlement", entitlements(ivy)["pro"]["active"] is False, entitlements(ivy))
    expect("...gated route refuses again", call("GET", "/v1/pro/ping", ivy), 402, "payment_required")
    rc.set("user-ivy", {"pro": {"expires_date": iso(3600)}})
    webhook({"type": "RENEWAL", "app_user_id": "user-ivy"})
    webhook({"type": "RENEWAL", "app_user_id": "user-ivy"})
    check("duplicate events are harmless", entitlements(ivy)["pro"]["active"] is True and len(entitlements(ivy)) == 1, entitlements(ivy))

    print("payments module — expiry takes effect by itself")
    rc.set("user-ivy", {"pro": {"expires_date": iso(2)}})
    webhook({"type": "RENEWAL", "app_user_id": "user-ivy"})
    check("active right after", entitlements(ivy)["pro"]["active"] is True, "")
    time.sleep(3.5)
    check("inactive a moment later with NO further webhook", entitlements(ivy)["pro"]["active"] is False, entitlements(ivy))
    expect("...and the gated route refuses", call("GET", "/v1/pro/ping", ivy), 402, "payment_required")

    print("payments module — entitlement shapes")
    rc.set("user-kim", {"lifetime": {"expires_date": None, "product_identifier": "unlock"}})
    webhook({"type": "NON_RENEWING_PURCHASE", "app_user_id": "user-kim"})
    lifetime = entitlements(kim).get("lifetime", {})
    check("lifetime unlock: active, never expires", lifetime.get("active") is True and lifetime.get("expires_at") is None, lifetime)
    expect("...but it is not 'pro'", call("GET", "/v1/pro/ping", kim), 402, "payment_required")
    rc.set("user-lee", {"pro": {"expires_date": iso(-60), "grace_period_expires_date": iso(3600)}})
    webhook({"type": "BILLING_ISSUE", "app_user_id": "user-lee"})
    check("billing grace period keeps access", entitlements(lee)["pro"]["active"] is True, entitlements(lee))
    rc.set("user-mia", {"pro": {"expires_date": "garbage"}})
    webhook({"type": "RENEWAL", "app_user_id": "user-mia"})
    check("an unreadable expiry means expired, never forever", entitlements(mia)["pro"]["active"] is False, entitlements(mia))

    print("payments module — transfer and failures")
    rc.set("user-nia", {"pro": {"expires_date": iso(3600)}})
    rc.set("user-ois", {})
    status, body = webhook({"type": "TRANSFER", "transferred_from": ["user-ois"], "transferred_to": ["user-nia"]})
    check("a transfer refreshes both users", status == 200 and body == {"refreshed": 2}, (status, body))
    check("...and the new owner has access", entitlements(nia)["pro"]["active"] is True, entitlements(nia))
    status, body = webhook({"type": "RENEWAL", "app_user_id": "user-boom"})
    check("if RevenueCat fails the webhook answers 500 so it is retried", status == 500, (status, body))

    print("payments module — refresh route")
    rc.set("user-jo", {"pro": {"expires_date": iso(3600)}})
    first = rc.calls_for("GET", "user-jo")
    status, body = call("POST", "/v1/entitlements/refresh", jo, {})
    names = {e["name"]: e for e in body["entitlements"]} if status == 200 else {}
    check("refresh pulls the purchase without waiting for a webhook", names.get("pro", {}).get("active") is True, (status, body))
    check("...by asking RevenueCat once", rc.calls_for("GET", "user-jo") == first + 1, rc.calls)
    call("POST", "/v1/entitlements/refresh", jo, {})
    check("an immediate second refresh is throttled (no new call)", rc.calls_for("GET", "user-jo") == first + 1, rc.calls)
    time.sleep(5.5)
    call("POST", "/v1/entitlements/refresh", jo, {})
    check("after the interval it asks again", rc.calls_for("GET", "user-jo") == first + 2, rc.calls)
    expect("refresh while RevenueCat is down is a clear 502", call("POST", "/v1/entitlements/refresh", signer.user("user-boom"), {}), 502, "payments_upstream_unavailable")

    print("payments module — account deletion")
    rc.set("user-ivy", {"pro": {"expires_date": iso(3600)}})
    webhook({"type": "RENEWAL", "app_user_id": "user-ivy"})
    check("ivy is paid before deleting", entitlements(ivy)["pro"]["active"] is True, "")
    expect("ivy deletes her account", call("DELETE", "/v1/account", ivy), 204)
    check("her entitlements are gone", entitlements(ivy) == {}, entitlements(ivy))
    expect("...and so is her access", call("GET", "/v1/pro/ping", ivy), 402, "payment_required")
    check("her record was erased at RevenueCat too", rc.calls_for("DELETE", "user-ivy") == 1, rc.calls)

