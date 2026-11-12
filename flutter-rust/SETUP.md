# Setup — from template to running app

This stack is a **complete, runnable app**: Flutter project, compiled-in Rust library, generated bindings, and a Worker API are all in the repo. Steps 1–2 get it running in a few minutes. Steps 3 onward make it yours.

**Prerequisites**

| Tool | Check | Install |
|---|---|---|
| Flutter 3.44+ | `flutter --version` | https://docs.flutter.dev/get-started |
| Rust (stable) | `cargo --version` | https://rustup.rs |
| Node.js 20+ | `node --version` | for `npx wrangler` |
| Xcode 15+ and/or Android SDK | `flutter doctor` | iOS deployment target is 15.0 |

One-time Rust setup:

```bash
# iOS + Android + Worker targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios \
  aarch64-linux-android armv7-linux-androideabi x86_64-linux-android wasm32-unknown-unknown
rustup component add rustfmt
```

Only needed when you change Rust code exposed to Dart (version must match `pubspec.yaml`):

```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0
```

---

## Step 1 — Create the project

```bash
# Once: clone the templates repo somewhere you can find it
git clone https://github.com/dtruong21/ai-project-template.git ~/Documents/templates

# Each new project: one command
~/Documents/templates/scripts/new-project.sh flutter-rust ~/Documents/my-new-app
cd ~/Documents/my-new-app
```

The helper copies this stack, creates `.env` from `.env.example`, and starts a fresh git repo on `main`.

---

## Step 2 — Run it

Terminal 1 — the API, with a local database:

```bash
cd rust/api
npx wrangler d1 migrations apply DB --local
npx wrangler dev                       # http://localhost:8787
```

Terminal 2 — the app:

```bash
flutter pub get
flutter devices                        # pick a simulator/emulator id
flutter run -d <device-id>
```

The first build compiles the Rust library and takes a few minutes. The home screen shows three checks:

| Check | Expected now | Fix if red |
|---|---|---|
| Rust bridge | ✅ loaded | rebuild; see Troubleshooting |
| API | ✅ reachable | is `wrangler dev` running? Android emulator: set `API_BASE_URL=http://10.0.2.2:8787` in `.env` |
| Firebase Auth | ❌ not configured | expected — Step 3 |

Tap **Send feedback** and send an empty message: "Feedback can't be empty." comes from the Rust validation in `rust/shared`. With text, you get "Sign in is required" until Step 3.

Run the tests:

```bash
flutter test                           # widget tests
(cd rust && cargo test)                # shared validation rules
(cd rust/core && cargo test)           # app-side payload builders
```

---

## Step 3 — Connect Firebase (Auth only)

1. Create a project at https://console.firebase.google.com
2. **Authentication → Sign-in method → enable Anonymous.** (Add Email/Google/Apple later. Avoid SMS sign-in — it is billed per message and is the largest cost at scale.)
3. Do **not** create Firestore, Functions or Storage — this stack does not use them.
4. Generate the app config — this **replaces** the placeholder `lib/firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

Commit the generated file. Its API key is not a secret — the Worker verifying the ID token is the security model (`docs/SECURITY.md`).

5. Tell the Worker which Firebase project to trust — `rust/api/wrangler.toml`:

```toml
[vars]
FIREBASE_PROJECT_ID = "<your-firebase-project-id>"
```

6. Restart `wrangler dev` and the app (full restart, not hot reload). All three checks are now green. Send feedback, then look at the row:

```bash
cd rust/api
npx wrangler d1 execute DB --local --command "SELECT uid, category, body FROM feedback"
```

That is the whole path working: Flutter → Rust validation → HTTPS with Firebase ID token → Worker verifies → D1.

---

## Step 4 — Make it yours

**Names and ids.** The template ships as `com.example.app` / "App". Change:

| What | Where |
|---|---|
| Android application id + namespace | `android/app/build.gradle.kts` (`applicationId`, `namespace`) and the folder path under `android/app/src/main/kotlin/` |
| Android display name | `android/app/src/main/AndroidManifest.xml` → `android:label` |
| iOS bundle id | `ios/Runner.xcodeproj/project.pbxproj` → every `PRODUCT_BUNDLE_IDENTIFIER` (or Xcode → Runner → Signing) |
| iOS display name | `ios/Runner/Info.plist` → `CFBundleDisplayName` |
| App title in code | `lib/app.dart` → `title:` and the `AppBar` in `lib/features/home/` |
| Worker + database name | `rust/api/wrangler.toml` → `name`, `database_name` |

Do this **before** `flutterfire configure` if you can — Firebase registers the bundle ids. If you already ran it, run it again after renaming.

The Dart package name stays `app` (in `pubspec.yaml` and every `package:app/...` import) and the Rust crate stays `rust_lib_app`. Neither is user-visible; renaming them touches generated code for no gain.

**Doc placeholders.** Find/replace in your editor:

| Placeholder | What to put |
|---|---|
| `{{PROJECT_NAME}}` | Your project's display name |
| `{{ONE_LINE_PITCH}}` | One sentence — what it does |
| `{{WHY}}` | One paragraph — why it exists |
| `{{DIFFERENTIATOR}}` | One sentence — what makes it different |
| `{{DATE}}` | Today's date |
| `{{N}}` (in PRD constraints) | Number of weeks budgeted |

```bash
PROJECT_NAME="MyApp" grep -rl "{{PROJECT_NAME}}" . --exclude-dir=.dart_tool --exclude-dir=build --exclude-dir=target \
  | xargs sed -i "" "s/{{PROJECT_NAME}}/$PROJECT_NAME/g"
```

Then delete this `SETUP.md` — it is not project content.

---

## Step 5 — Pick a design system

The app ships with `notion-github` pre-installed in `lib/core/design/`. Two more live in [`design-systems/`](design-systems/):

| System | Vibe | Best for |
|---|---|---|
| `notion-github` (default) | Calm, data-dense | Trackers, productivity |
| `linear-minimal` | Sharp, monochrome | SaaS tools, dev apps |
| `warm-playful` | Soft, rounded | Consumer, wellness, habit, journal |

```bash
./scripts/pick-design-system.sh warm-playful     # or keep the default: notion-github
```

The script copies `tokens.dart` + `theme.dart` into `lib/core/design/`, `DESIGN.md` into `docs/`, and removes `design-systems/`. Every system exposes the same `buildTheme(Brightness)`, so `lib/app.dart` needs no change — restart the app to see it.

**Switching later is expensive.** After 3+ screens expect 1–2 days. Pick deliberately.

---

## Step 6 — Define your pillars in `docs/PRD.md`

Replace the pillar placeholders with 2–4 *actual* pillars. **This is the most important step.** Every future feature is scored against them by `/spec` and `/scope-check`.

A good pillar is one sentence, names a user outcome (not a feature), and is in tension with the others. "Be easy to use" and "Push notifications" are not pillars.

---

## Step 7 — Analytics and crash reporting (optional until launch prep)

The typed event layer in [`lib/core/analytics/`](lib/core/analytics/) works now: in debug builds events print to the console. To send them somewhere:

```bash
flutter pub add posthog_flutter sentry_flutter
```

Set `POSTHOG_KEY` and `SENTRY_DSN` in `.env`, uncomment the PostHog lines in `lib/core/analytics/client.dart`, and initialize both in `lib/core/bootstrap.dart`. Write your North-Star Metric into `docs/TRACKING-PLAN.md` first — no event is added before the NSM is defined.

---

## Step 8 — Deploy the API

```bash
cd rust/api
npx wrangler login
npx wrangler d1 create <database_name>      # paste the printed id into wrangler.toml → database_id
npx wrangler d1 migrations apply DB --remote
npx wrangler deploy                         # prints the https URL
```

Use that URL as `API_BASE_URL` in the `.env` you build releases with. Release checklist: `docs/RELEASE.md`. Before real traffic, read "Known gaps" in `docs/SECURITY.md` (no rate limiting yet).

---

## Step 9 — The development loop

```
/spec    →  /design   →  /build   →  /test   →  /release
```

Each command runs in the main loop as a role "hat" (except `/test`, which spawns the `qa-engineer` sub-agent). Each phase's output is the next phase's input. **Don't skip.** Not sure where to pick up: `/next`.

First real feature: `/spec <feature>`, then `/d1 <table> <field:type> ...` scaffolds the data slice (migration, shared Rust model + validation, Worker route, app payload builder).

**What to re-run after which change**

| You changed | Run |
|---|---|
| `rust/shared/` or `rust/api/` | `(cd rust && cargo test)`; `wrangler dev` rebuilds on save |
| `rust/core/src/api/` (anything Dart calls) | `flutter_rust_bridge_codegen generate`, `(cd rust/core && cargo test)`, then **full restart** of the app |
| A `@riverpod` / freezed / typed-route file | `dart run build_runner build --delete-conflicting-outputs` (or `watch -d` while developing) |
| A file in `rust/api/migrations/` | `npx wrangler d1 migrations apply DB --local` |

Generated files (`*.g.dart`, `lib/src/rust/`, `rust/core/src/frb_generated.rs`) are committed so a clone runs without codegen. Regenerate them; never edit them by hand.

---

## Troubleshooting

- **iOS: `Binary ... Flutter.framework/Flutter does not contain architectures "arm64 x86_64"`** — seen with Flutter 3.44 + Xcode 27 when running `flutter build ios --simulator`. Use `flutter run -d <simulator-id>` (builds one architecture) or upgrade Flutter.
- **iOS: deployment target error mentioning 13.0** — the project and `ios/Podfile` are set to 15.0; run `cd ios && pod install` if Pods are stale.
- **"Rust bridge: not loaded" or a content-hash panic at start** — bindings are stale: `flutter_rust_bridge_codegen generate`, then `flutter clean && flutter run`.
- **Build fails with "No file or variants found for asset: .env"** — `cp .env.example .env`.
- **API unreachable on Android emulator** — `localhost` is the emulator itself; use `http://10.0.2.2:8787`.
- **API unreachable on a physical phone** — use your computer's LAN IP and run `npx wrangler dev --ip 0.0.0.0`.
- **401 "Server misconfigured: FIREBASE_PROJECT_ID is not set"** — Step 3.5.
- **401 "Invalid or expired token" after Step 3** — `FIREBASE_PROJECT_ID` does not match the project in `lib/firebase_options.dart`.

---

## What was and was not verified

Verified (2026-11-12, Flutter 3.44.6, Xcode 27.2, cargo 1.100, flutter_rust_bridge 2.13, wrangler 4.161): Steps 1–2 on an iOS simulator — app builds with the Rust library, bridge loads, API health check passes, Rust validation message reaches the UI; all test suites pass; the Worker accepts a correctly signed token and rejects forged ones (tested with a local signing key).

**Not verified:** Step 3 with a real Firebase project (so the signed-in round trip from the app, and verification against Google's live keys), any Android build, a physical device, `wrangler deploy`, and the Codemagic workflows (they do not build the Rust crate yet — see the note in `codemagic.yaml`). Update this section after your first full setup.
