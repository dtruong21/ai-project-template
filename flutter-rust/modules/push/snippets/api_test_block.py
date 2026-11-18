    print("push module")
    fcm = MODULE_STATE["fcm"]
    erin, frank, grace = signer.user("user-erin"), signer.user("user-frank"), signer.user("user-grace")

    def admin(body, key="test-admin-key"):
        request = urllib.request.Request(BASE + "/v1/admin/push", data=json.dumps(body).encode(), method="POST")
        request.add_header("Content-Type", "application/json")
        if key is not None:
            request.add_header("X-Admin-Key", key)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, json.loads(response.read().decode())
        except urllib.error.HTTPError as error:
            text = error.read().decode(errors="replace")
            try:
                return error.code, json.loads(text)
            except ValueError:
                return error.code, text

    def send(uid, title="Hello", body="World", data=None):
        status, result = admin({"uid": uid, "title": title, "body": body, "data": data or {}})
        if status == 200:
            return result
        # Not a report: make every count obviously wrong instead of crashing the test run.
        return {"sent": -1, "removed": -1, "failed": -1, "status": status}

    for method, path in [("PUT", "/v1/push/token"), ("DELETE", "/v1/push/token")]:
        expect(f"push: no token: {method} {path}", call(method, path, body={}), 401, "unauthenticated")

    expect("register a device", call("PUT", "/v1/push/token", erin, {"token": "erin-phone:1", "platform": "ios"}), 204)
    expect("registering twice is fine", call("PUT", "/v1/push/token", erin, {"token": "erin-phone:1", "platform": "ios"}), 204)
    expect("token with spaces is rejected", call("PUT", "/v1/push/token", erin, {"token": "has space", "platform": "ios"}), 422, "validation_failed")
    expect("token that is too long is rejected", call("PUT", "/v1/push/token", erin, {"token": "a" * 600, "platform": "ios"}), 422, "validation_failed")
    expect("unknown platform", call("PUT", "/v1/push/token", erin, {"token": "x", "platform": "linux"}), 400, "invalid_body")
    expect("smuggled uid field", call("PUT", "/v1/push/token", erin, {"token": "x", "platform": "ios", "uid": "user-frank"}), 400, "invalid_body")

    print("push module — operator route")
    expect("admin: no key", admin({"uid": "user-erin", "title": "t", "body": "b"}, key=None), 401, "unauthenticated")
    expect("admin: wrong key", admin({"uid": "user-erin", "title": "t", "body": "b"}, key="nope"), 401, "unauthenticated")
    expect("admin: a user's ID token is not an admin key", admin({"uid": "user-erin", "title": "t", "body": "b"}, key=erin), 401, "unauthenticated")
    expect("admin: empty title", admin({"uid": "user-erin", "title": " ", "body": "b"}), 422, "validation_failed")
    expect("admin: reserved data key", admin({"uid": "user-erin", "title": "t", "body": "b", "data": {"google.x": "1"}}), 422, "validation_failed")
    expect("admin: smuggled field", admin({"uid": "user-erin", "title": "t", "body": "b", "token": "x"}), 400, "invalid_body")
    check("nothing was sent by any rejected request", len(fcm.messages) == 0, fcm.messages)

    print("push module — sending")
    result = send("user-erin", "Hello", "World", {"order_id": "42"})
    check("send reaches the registered device", result == {"sent": 1, "removed": 0, "failed": 0}, result)
    delivered = fcm.messages_to("erin-phone:1")
    check("message has the title, text and data", len(delivered) == 1
          and delivered[0]["notification"] == {"title": "Hello", "body": "World"}
          and delivered[0]["data"] == {"order_id": "42"}, delivered)
    check("the signed assertion was exactly what Google requires", fcm.rejected_assertions == [] and fcm.tokens_issued == 1,
          (fcm.rejected_assertions, fcm.tokens_issued))
    send("user-erin")
    check("the access token is reused, not minted per send", fcm.tokens_issued == 1, fcm.tokens_issued)
    check("a user with no devices gets nothing", send("user-nobody") == {"sent": 0, "removed": 0, "failed": 0}, "")

    call("PUT", "/v1/push/token", erin, {"token": "erin-tablet:2", "platform": "android"})
    check("every device of the user gets it", send("user-erin")["sent"] == 2, "")

    print("push module — dead and failing devices")
    call("PUT", "/v1/push/token", erin, {"token": "erin-dead:3", "platform": "ios"})
    result = send("user-erin")
    check("a dead token is reported and removed", result == {"sent": 2, "removed": 1, "failed": 0}, result)
    check("...and is gone for next time", send("user-erin") == {"sent": 2, "removed": 0, "failed": 0}, "")
    call("PUT", "/v1/push/token", erin, {"token": "erin-boom:4", "platform": "ios"})
    check("a server error counts as failed but keeps the token", send("user-erin") == {"sent": 2, "removed": 0, "failed": 1}, "")
    check("...and is retried next time", send("user-erin")["failed"] == 1, "")
    expect("erin removes the failing device", call("DELETE", "/v1/push/token", erin, {"token": "erin-boom:4"}), 204)
    check("...so it is no longer tried", send("user-erin") == {"sent": 2, "removed": 0, "failed": 0}, "")

    print("push module — ownership")
    before = len(fcm.messages_to("erin-phone:1"))
    expect("frank 'removing' erin's token is a harmless no-op", call("DELETE", "/v1/push/token", frank, {"token": "erin-phone:1"}), 204)
    send("user-erin")
    check("erin's device still gets her notifications", len(fcm.messages_to("erin-phone:1")) == before + 1, "")
    expect("a device signing in as frank takes the token over", call("PUT", "/v1/push/token", frank, {"token": "erin-phone:1", "platform": "ios"}), 204)
    before = len(fcm.messages_to("erin-phone:1"))
    check("erin no longer reaches that device", send("user-erin")["sent"] == 1 and len(fcm.messages_to("erin-phone:1")) == before, "")
    check("frank does", send("user-frank")["sent"] == 1 and len(fcm.messages_to("erin-phone:1")) == before + 1, "")

    print("push module — per-user cap")
    for i in range(12):
        call("PUT", "/v1/push/token", grace, {"token": f"grace-{i:02d}", "platform": "android"})
    check("only the newest 10 devices are kept", send("user-grace")["sent"] == 10, "")

    print("push module — account deletion")
    expect("erin deletes her account", call("DELETE", "/v1/account", erin), 204)
    sent_before = len(fcm.messages)
    check("her devices are gone", send("user-erin") == {"sent": 0, "removed": 0, "failed": 0}, "")
    check("...and nothing reached FCM for her", len(fcm.messages) == sent_before, "")
    call("DELETE", "/v1/account", frank)
    call("DELETE", "/v1/account", grace)
    check("frank's and grace's devices are gone too", send("user-frank")["sent"] == 0 and send("user-grace")["sent"] == 0, "")

