# Push module

Push notifications through Firebase Cloud Messaging (FCM). Users opt in from **Settings → Notifications**; your server sends to a user's devices; dead devices clean themselves up; everything is erased with the account.

## Enable

```bash
python3 modules/push/apply.py
```

Then do the one-time setup below — the code cannot do it for you. Until it is done the switch shows "Available once Firebase is set up" and the app works normally.

## One-time setup

**1. Firebase.** Push needs a real Firebase project: `flutterfire configure` (SETUP Step 3). In the Firebase console, Cloud Messaging API (V1) must be enabled (it is by default on new projects).

**2. iOS.** Push only works on a real iPhone (the Simulator cannot get a device token).
- Apple Developer → Keys → create an APNs key (`.p8`); upload it in Firebase console → Project settings → Cloud Messaging → Apple app configuration.
- Xcode → Runner → Signing & Capabilities → add **Push Notifications** and **Background Modes → Remote notifications**. This edits the Xcode project, which `apply.py` deliberately does not touch.

**3. Android.** `apply.py` adds the `POST_NOTIFICATIONS` permission Android 13+ requires. Nothing else beyond `flutterfire configure`.

**4. Let the Worker send.** Create a service account that can do *only* this — not the default Firebase Admin one, which can read and change your whole project:

```bash
PROJECT=<your-firebase-project-id>
gcloud iam service-accounts create fcm-sender --project $PROJECT
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:fcm-sender@$PROJECT.iam.gserviceaccount.com \
  --role roles/firebasecloudmessaging.admin
gcloud iam service-accounts keys create key.json \
  --iam-account fcm-sender@$PROJECT.iam.gserviceaccount.com

cd rust/api
npx wrangler secret put FCM_SERVICE_ACCOUNT < ../../key.json
rm ../../key.json                      # the secret now lives only in Cloudflare
```

(Check the role name in the console if `gcloud` rejects it: IAM → Roles → "Firebase Cloud Messaging Admin".)

**5. Optional: the operator route.** Off unless you set a key:

```bash
openssl rand -hex 32 | npx wrangler secret put PUSH_ADMIN_KEY      # save the value in your password manager
```

## Sending

From Worker code — the real entry point:

```rust
use shared::push::PushMessage;

let report = crate::push::send_to_user(&env, &uid, &PushMessage {
    title: "Your order shipped".into(),
    body: "Tap to track it".into(),
    data: [("order_id".to_string(), "42".to_string())].into(),   // delivered to the app as strings
}).await?;     // SendReport { sent, removed, failed }
```

From a terminal or a cron job (needs `PUSH_ADMIN_KEY`):

```bash
curl -X POST https://<your-worker>/v1/admin/push \
  -H "X-Admin-Key: $PUSH_ADMIN_KEY" -H 'Content-Type: application/json' \
  -d '{"uid":"<firebase uid>","title":"Hello","body":"World","data":{"order_id":"42"}}'
```

## What you get

| Route | Who | Does |
|---|---|---|
| `PUT /v1/push/token` | signed-in user | register this device (idempotent) |
| `DELETE /v1/push/token` | signed-in user | remove this device (always 204 — nothing to probe) |
| `POST /v1/admin/push` | operator key | send to one user; 404 unless `PUSH_ADMIN_KEY` is set |

- A device token belongs to whoever registered it last, so a phone that signs in as someone else stops notifying the previous user.
- At most 10 devices per user; the newest win.
- A token FCM reports as dead (app uninstalled) is deleted on the next send.
- Turning the switch off unregisters the device and deletes the local token; it works offline.
- The permission dialog appears only when the user turns the switch on — never at launch.

## Security

- The service-account key is a Worker secret only; scope it as above.
- `PUSH_ADMIN_KEY` lets its holder notify **any user**. Treat it like a root password, compare is constant-time, and prefer calling `send_to_user` from your own Worker code.
- Notification text and `data` are validated in Rust (`rust/shared/src/push.rs`): length limits, and FCM-reserved data keys are rejected.
- Never put secrets or personal data in a notification: it appears on lock screens and passes through Apple/Google.
- `FCM_BASE_URL` exists only so `api_test.py` can point the Worker at a fake Google. Never set it on a deployed Worker.

## Ceilings

- **Workers CPU.** Signing the Google token request is pure-Rust RSA in wasm: tens of milliseconds once an hour per isolate. Fine on the Workers paid plan; the free plan's 10 ms CPU cap can reject it. If that bites, sign with WebCrypto instead.
- No topics, segments, scheduling, delivery analytics, images or action buttons.
- Tapping a notification just opens the app; `data` arrives but nothing routes on it. Wire it to your router when a feature needs it.
- Android does not show notifications while the app is open (iOS does). Handle `FirebaseMessaging.onMessage` where a feature needs it.
- Only on/off per user; no per-category preferences.

## Verified

Applied (together with the files module) to a copy of the template: 28 shared + 12 core Rust tests, 59 Flutter tests, and 129 API end-to-end checks (37 for this module) pass. The end-to-end tests run against a strict fake of Google's token and FCM endpoints that verifies the Worker's signed assertion (RS256 signature, issuer, scope, audience, lifetime) before issuing a token. Breaking the signed scope, the token-ownership check or the account-deletion cleanup on purpose makes the matching checks fail.

**Not verified:** real FCM, a real device or APNs, the Xcode capabilities, the Android 13 permission flow, and the free-plan CPU limit. The Firebase Messaging wrapper (`push_platform.dart`) compiles but is only exercised through a fake.
