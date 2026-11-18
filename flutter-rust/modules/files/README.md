# Files module

Upload, list, view and delete images and PDFs. Bytes go to R2 (no egress fee); a D1 row per file holds the owner and metadata.

## Enable

```bash
python3 modules/files/apply.py
npx wrangler r2 bucket create app-files        # once, before deploying
```

Then run the suites it prints. Local development needs nothing else: `wrangler dev` simulates R2.

## What you get

| Route | Does |
|---|---|
| `POST /v1/files?name=photo.png` | upload (the body is the file) → 201 + metadata |
| `GET /v1/files?limit=&cursor=` | the caller's files, newest first, paged |
| `GET /v1/files/:id` | the bytes |
| `DELETE /v1/files/:id` | delete row and bytes |

App: **Settings → My files** — list, add an image from the gallery, tap to preview, delete with confirmation, all four states.

## Limits (edit in `rust/shared/src/files.rs`)

- 10 MB per file, 100 files per user (`403 quota_exceeded`, `413 too_large`).
- PNG, JPEG, GIF, WebP and PDF only.
- The app picks gallery images only. For PDFs and other files add the `file_picker` package and return its result from `filePickerProvider` — nothing else changes.

## Security properties (each is covered by `api_test.py`)

- **The client's content type is ignored.** The type is read from the file's first bytes; anything not on the allowlist is rejected, so an HTML or SVG file renamed `.png` cannot be uploaded and served back as a page.
- Downloads carry `X-Content-Type-Options: nosniff` and `Content-Security-Policy: default-src 'none'; sandbox`; PDFs are sent as attachments.
- File names are reduced to letters, digits, space and `. - _ ( )` so they are safe in lists and headers.
- Someone else's file and a missing file are both `404` — ids cannot be probed.
- Deleting a file or the account removes the stored bytes, not just the row. The test looks at R2 itself to prove it.
- Account deletion removes the stored files first; if that fails nothing is deleted and the user can retry.

## Ceilings

- Uploads and downloads pass through the Worker and are held in memory. Fine to ~10–50 MB. Past that, or at high traffic, switch to presigned R2 URLs so bytes skip the Worker.
- The quota check is count-then-insert: a burst of parallel uploads can overshoot it by a few.
- No thumbnails: previews download the full image. Add a resized copy at upload time if lists get image-heavy.
- No virus scanning. The allowlist and sandboxed responses limit what a hostile file can do; they do not inspect content.

## Verified

Applied to a copy of the template: 21 shared + 10 core Rust tests, 45 Flutter tests, and 92 API end-to-end checks (32 of them this module's) pass; breaking the ownership check or the R2 cleanup on purpose makes the matching check fail. **Not verified:** a real R2 bucket (local simulation only), the image picker on a device or simulator, files over a few MB.
