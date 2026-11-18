    print("files module")
    carol = signer.user("user-carol")
    png = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) + bytes(range(64))
    pdf = b"%PDF-1.4\n" + b"x" * 40

    def upload(token, data, name="photo.png", declared_type="image/png"):
        request = urllib.request.Request(BASE + "/v1/files?name=" + urllib.parse.quote(name), data=data, method="POST")
        request.add_header("Authorization", f"Bearer {token}")
        request.add_header("Content-Type", declared_type)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status, json.loads(response.read().decode())
        except urllib.error.HTTPError as error:
            text = error.read().decode()
            try:
                return error.code, json.loads(text)
            except ValueError:
                return error.code, text

    def download(token, file_id):
        request = urllib.request.Request(BASE + f"/v1/files/{file_id}")
        request.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status, response.read(), dict(response.headers)
        except urllib.error.HTTPError as error:
            return error.code, error.read(), dict(error.headers)

    def r2_has(file_id):
        """Is the object still in (local) R2? Looks at storage, not at the API."""
        result = subprocess.run(
            ["npx", "wrangler", "r2", "object", "get", f"app-files/{file_id}", "--local",
             "--persist-to", str(STATE_DIR), "--pipe"],
            cwd=API_DIR, env={**os.environ, "WRANGLER_SEND_METRICS": "false", "CI": "1"},
            capture_output=True,
        )
        return result.returncode == 0 and len(result.stdout) > 0

    for method, path in [("POST", "/v1/files"), ("GET", "/v1/files"), ("GET", "/v1/files/abc"), ("DELETE", "/v1/files/abc")]:
        expect(f"files: no token: {method} {path}", call(method, path, raw=b"x"), 401, "unauthenticated")

    status, created = upload(carol, png, name="my holiday (1).png")
    check("upload an image", status == 201 and created.get("content_type") == "image/png"
          and created.get("size") == len(png) and created.get("name") == "my holiday (1).png", (status, created))
    file_id = created.get("id", "missing") if isinstance(created, dict) else "missing"
    check("response has no uid", isinstance(created, dict) and "uid" not in created, created)
    status, pdf_meta = upload(carol, pdf, name="doc.pdf", declared_type="application/pdf")
    check("upload a pdf", status == 201 and pdf_meta.get("content_type") == "application/pdf", (status, pdf_meta))

    status, body, headers = download(carol, file_id)
    check("download returns the exact bytes", status == 200 and body == png, (status, len(body)))
    check("(storage check works) object is in R2", r2_has(file_id), file_id)
    check("download type comes from the content", headers.get("Content-Type") == "image/png", headers)
    check("download is nosniff and sandboxed",
          headers.get("X-Content-Type-Options") == "nosniff"
          and "sandbox" in headers.get("Content-Security-Policy", ""), headers)
    status, body, headers = download(carol, pdf_meta.get("id", "missing"))
    check("pdf is served as an attachment", "attachment" in headers.get("Content-Disposition", ""), headers)

    status, html = upload(carol, b"<html><script>alert(1)</script></html>", name="x.png", declared_type="image/png")
    check("html renamed .png is rejected (client's type ignored)", status == 422 and html["error"]["code"] == "validation_failed", (status, html))
    status, svg = upload(carol, b"<svg xmlns='http://www.w3.org/2000/svg'/>", name="x.svg", declared_type="image/svg+xml")
    check("svg is rejected", status == 422, (status, svg))
    status, empty = upload(carol, b"")
    check("empty file is rejected", status == 422, (status, empty))
    status, big = upload(carol, png + bytes(10 * 1024 * 1024))
    check("file over 10 MB is rejected with too_large", status == 413 and big["error"]["code"] == "too_large", (status, big if isinstance(big, dict) else big[:80]))
    status, evil = upload(carol, png, name='evil"\r\nSet-Cookie: x=1.pdf')
    check("hostile file name is cleaned", status == 201 and '"' not in evil["name"] and "\n" not in evil["name"], (status, evil))

    status, listing = call("GET", "/v1/files", carol)
    check("list shows the caller's files newest first", status == 200 and len(listing["items"]) == 3, listing)
    status, page = call("GET", "/v1/files?limit=2", carol)
    check("list is paged", len(page["items"]) == 2 and page["next_cursor"], page)
    status, page2 = call("GET", f"/v1/files?limit=2&cursor={page['next_cursor']}", carol)
    check("second page has the rest", len(page2["items"]) == 1 and page2["next_cursor"] is None, page2)

    expect("bob cannot download carol's file", call("GET", f"/v1/files/{file_id}", bob), 404, "not_found")
    expect("bob cannot delete carol's file", call("DELETE", f"/v1/files/{file_id}", bob), 404, "not_found")
    status, bobs_list = call("GET", "/v1/files", bob)
    check("bob's list is empty", status == 200 and bobs_list["items"] == [], bobs_list)
    status, body, _ = download(carol, file_id)
    check("carol's file survived bob's attempts", status == 200 and body == png, status)

    expect("carol deletes her image", call("DELETE", f"/v1/files/{file_id}", carol), 204)
    status, body, _ = download(carol, file_id)
    check("deleted file is gone", status == 404, status)
    check("deleting a file removes its stored bytes", not r2_has(file_id), file_id)

    expect("carol deletes her account", call("DELETE", "/v1/account", carol), 204)
    status, after = call("GET", "/v1/files", carol)
    check("account deletion removed carol's files", status == 200 and after["items"] == [], after)
    status, _, _ = download(carol, pdf_meta.get("id", "missing"))
    check("...and their bytes through the API", status == 404, status)
    check("account deletion removed the stored bytes from R2", not r2_has(pdf_meta.get("id", "missing")), pdf_meta)

    print("files module — quota")
    dave = signer.user("user-dave")
    for i in range(100):
        status, _ = upload(dave, png, name=f"f{i}.png")
        if status != 201:
            check(f"upload {i + 1} within quota", False, status)
            break
    status, over = upload(dave, png, name="one-too-many.png")
    check("101st file hits the quota", status == 403 and over["error"]["code"] == "quota_exceeded", (status, over))
    call("DELETE", "/v1/account", dave)

