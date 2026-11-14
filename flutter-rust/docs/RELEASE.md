# Release Runbook

How to take {{PROJECT_NAME}} from "code complete" to shipping in App Store + Play Store.

---

## Step 0 — One-time setup (~$124 total)

| Item | Cost | Required for |
|------|------|--------------|
| Apple Developer Program | $99/yr | iOS dev build, TestFlight, App Store |
| Google Play Console | $25 one-time | Play Store submission |
| Codemagic account | Free tier (500 build min/mo) | CI builds, store submission |
| Firebase project (Blaze plan if Functions) | Free tier viable | Backend |
| Privacy/Terms hosting (GitHub Pages or similar) | Free | App Store / Play Store requirement |

Sign up:
- Apple: https://developer.apple.com/programs/enroll/
- Google: https://play.google.com/console/signup
- Codemagic: https://codemagic.io/
- Firebase CLI: `npm install -g firebase-tools && firebase login`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

---

## Step 1 — Configure FlutterFire

Generates `lib/firebase_options.dart` from your Firebase project. **Commit this file** — the web API key it contains is not secret (security comes from the Worker verifying the Firebase ID token on every request).

```bash
flutterfire configure --project=<your-firebase-project-id>
```

Pick the platforms you'll ship (iOS, Android, optionally web). This wires `GoogleService-Info.plist` (iOS), `google-services.json` (Android), and the Dart options file in one shot.

---

## Step 2 — Brand assets

Configured via `pubspec.yaml`, generated with two packages.

### App icon (`flutter_launcher_icons`)

Drop a 1024×1024 PNG at `assets/branding/icon.png` (no transparency, no rounded corners — the stores add them).

```yaml
# pubspec.yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/branding/icon.png"
  adaptive_icon_background: "#FFFFFF"   # or "assets/branding/icon_background.png"
  adaptive_icon_foreground: "assets/branding/icon_foreground.png"
  remove_alpha_ios: true
```

Generate:
```bash
dart run flutter_launcher_icons
```

### Splash screen (`flutter_native_splash`)

```yaml
# pubspec.yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: "assets/branding/splash.png"   # 1152×1152 centered
  android_12:
    image: "assets/branding/splash_android12.png"
    color: "#FFFFFF"
```

Generate:
```bash
dart run flutter_native_splash:create
```

Re-run both whenever the source asset changes. Generated native files are committed (they're part of the platform projects).

---

## Step 3 — Host Privacy + Terms

Required by App Store and Play Store. Markdown lives in `docs/legal/`. Host options:

- **GitHub Pages** (free, ~10 min) — push to a public repo, enable Pages.
- **Notion** — paste, "Publish to web", copy URL.
- **Your domain** — host the rendered HTML.

Update `.env`:
```
PRIVACY_URL=https://your.url/privacy
TERMS_URL=https://your.url/terms
```

(These are read via `flutter_dotenv` — they bundle into the app, same threat model as the Firebase web config.)

---

## Step 4 — Deploy the API (Worker + D1)

Always before cutting the app build — a new app must never meet an old API. Keep API changes backward compatible for one release (old app versions stay in the wild).

```bash
(cd rust && cargo test)                 # shared validation rules
(cd rust/core && cargo test)            # app-side payload builders
cd rust/api
npx wrangler d1 migrations apply DB --remote
npx wrangler deploy
curl https://<your-worker-url>/health   # expect: ok
cd ../..
```

The Workers free plan covers early testing; the paid plan ($5/month base) lifts the daily request cap. Account-deletion must delete the user's D1 rows — add a `DELETE /v1/account` route before store submission.

---

## Step 5 — Configure Codemagic

Codemagic reads `codemagic.yaml` at the repo root. The template ships a baseline with three workflows: `pr-checks`, `staging`, `production`.

Connect the repo:
1. Codemagic dashboard → Add application → connect Gitea/GitHub.
2. Configure environment variables in the Codemagic UI (under the app's "Environment variables" tab):
   - `CLOUDFLARE_API_TOKEN` (Cloudflare dashboard → API Tokens → "Edit Cloudflare Workers" template) — only if CI deploys the Worker
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS` (JSON)
   - `CERTIFICATE_PRIVATE_KEY` (iOS signing — Codemagic Code Signing manages the rest)

The first build picks up signing credentials via Codemagic's managed code signing — no certs on disk locally.

---

## Step 6 — Cut the first dev build (Android first, free)

Android dev builds don't require Apple Developer Program. Start there:

```bash
flutter build apk --release
# OR via Codemagic UI: trigger the staging workflow on android
```

For iOS (needs Apple Developer):
```bash
flutter build ipa --release
# OR via Codemagic UI: trigger the staging workflow on ios
```

Install the APK/IPA on a device, verify it boots and signs in.

---

## Step 7 — Wire native auth providers (after dev build)

With a real bundle ID from a dev build, create OAuth credentials:

- **Google iOS**: Google Cloud → Credentials → Create iOS OAuth Client ID, bundle ID = your production bundle. Copy `REVERSED_CLIENT_ID` into `ios/Runner/Info.plist` URL schemes.
- **Google Android**: Google Cloud → Credentials → Create Android OAuth Client ID. SHA-1 from `cd android && ./gradlew signingReport` (debug) or Codemagic's signing cert (release).
- **Apple Sign-In** (required if Google is enabled, per App Store policy): Apple Developer → Identifiers → enable "Sign In with Apple" capability for the bundle ID. Firebase Console → Authentication → enable Apple. The `firebase_auth` package handles the rest on iOS 13+.

---

## Step 8 — Store metadata

Fill in `docs/STORE_METADATA.md`. Required:

- Short description (Play Store, 80 chars)
- Full description (4000 chars each store)
- Keywords (App Store, 100 chars comma-separated)
- Promotional text (App Store, 170 chars, updatable post-submit)
- What's New (per version)
- Privacy policy URL (Step 3)
- Support URL (your contact email or page)

---

## Step 9 — Screenshots

Take from the actual release build (NOT the debug build — looks different). Use iPhone 17 Pro simulator and Pixel 8 emulator.

**iOS sizes:**
- 6.9" iPhone: 1320×2868
- 6.5" iPhone: 1242×2688

**Android:**
- Phone: 1080×1920 minimum, 16:9

5 screens recommended — pick the most product-defining ones.

---

## Step 10 — TestFlight / Internal track

Bump `version:` in `pubspec.yaml` first (format: `X.Y.Z+buildNumber`, e.g. `0.1.0+1`).

Trigger Codemagic's `production` workflow (or run locally):

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
flutter build appbundle --release

# Submit (Codemagic's publishing block handles this automatically, or use fastlane locally):
# iOS: App Store Connect API upload
# Android: Play Console internal track upload
```

First iOS submission asks for the ASC App ID — create the listing in App Store Connect first.

Invite 5–10 testers. Run a 1–2 week closed beta. Listen.

---

## Step 10.5 — Desktop and web builds

Codemagic workflows: `macos_release`, `windows_release`, `web_release` (UNVERIFIED — see the note in `codemagic.yaml`).

- **macOS:** needs a Developer ID certificate (same $99 Apple program) to sign, then notarization with `xcrun notarytool`. Unsigned apps are blocked by Gatekeeper. Mac App Store is a separate listing and needs the sandbox entitlements reviewed.
- **Windows:** the workflow produces a folder with the `.exe` and dlls, not an installer. Package as MSIX (`flutter pub add --dev msix`) or an installer tool, and sign it — unsigned installers trigger SmartScreen warnings. Microsoft Store is optional.
- **Web:** deploy `build/web` to your host and confirm it sends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, or the Rust wasm will not load. Check `crossOriginIsolated` in the browser console.

---

## Step 11 — Public launch

1. Bump `version:` in `pubspec.yaml` (PATCH for fixes, MINOR for features, bump the `+buildNumber` always)
2. Update `CHANGELOG.md`
3. Update "What's New" in store metadata
4. Trigger Codemagic `production` workflow on `main`
5. Codemagic publishes to TestFlight + Play Console production track
6. App Store review: 1–3 days
7. Play Store review: usually <24h

---

## Recurring releases

```bash
# After feature work:
# 1. Update CHANGELOG.md
# 2. Bump version: in pubspec.yaml (PATCH for fixes, MINOR for features; ALWAYS bump +buildNumber)
git tag v0.X.Y
git push --tags
# Codemagic auto-triggers production workflow on tag push (configured in codemagic.yaml)
```

### Dependency hygiene

Flutter and FlutterFire move fast. Stale deps cause friction at the worst time (right before submission). Treat this as part of every release:

```bash
# Check for outdated direct deps
flutter pub outdated --no-dev-dependencies

# Upgrade within constraints in pubspec.yaml
flutter pub upgrade

# For minor/major bumps that need pubspec edits, do them one package at a time:
# Test, run analyze, run integration_test, then commit per-package.
```

**Pin the Flutter SDK** via `.fvmrc` so CI and local builds match. When you bump the Flutter pin in `.fvmrc`, also bump it in `codemagic.yaml` AND bump Codemagic's cache key — the SDK cache is keyed aggressively and stale entries produce confusing build errors.

---

## When things break

- **Stale Codemagic SDK cache** — bump the cache key in `codemagic.yaml` after a Flutter pin change.
- **iOS code signing failure** — re-sync via Codemagic UI → Code Signing → re-fetch profiles. Locally, `flutter clean && cd ios && pod install --repo-update`.
- **Android signing failure** — verify upload keystore + JKS password in Codemagic env vars match Play Console.
- **App Store rejection** — usually privacy. Missing privacy URL or account deletion not actually deleting (`DELETE /v1/account` route, Step 4). Or a missing usage-description string in `ios/Runner/Info.plist`.
- **"App icon required" rejection** — Step 2 isn't done, or `flutter_launcher_icons` was run but the generated files weren't committed.
- **"No Firebase App '[DEFAULT]' has been created"** — `lib/firebase_options.dart` is gitignored or wasn't generated. Re-run `flutterfire configure` and commit the file.
