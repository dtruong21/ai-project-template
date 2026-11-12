# Template setup — instantiate a new Flutter + Rust + Cloudflare project

> **Partly verified:** the Rust workspace and the Worker (Step 7, local) were built and tested. Step 5.5 (bridge integration into a real Flutter project) and deploying were not run end to end — expect to adjust small things there, and update this file when you do.

This template gives you the Claude config, docs scaffolding, and a Rust workspace (shared rules + Worker API). You bring the actual Flutter project.

**Prerequisites:** Flutter SDK, Rust via [rustup](https://rustup.rs), Node.js (for `npx wrangler`), a Cloudflare account, a Firebase project. The steps below are the one-time bootstrap to wire them together.

---

## Step 1 — Bootstrap a new project from this template

This template lives in the `flutter-rust/` subdir of the multi-stack templates repo. Easiest way to start a new project:

```bash
# Once: clone the templates repo somewhere you can find it
git clone https://github.com/dtruong21/ai-project-template.git ~/Documents/templates

# Each new project: one command
~/Documents/templates/scripts/new-project.sh flutter-rust ~/Documents/my-new-app

# Then drop this SETUP.md after you're done — it's not project content
cd ~/Documents/my-new-app
rm SETUP.md
```

The helper copies `flutter-rust/` into the target dir (excluding `.git`) and initializes a fresh `git` repo on `main`.

(If you've already cloned the templates repo, you can manually `cp -R ~/Documents/templates/flutter-rust/. ~/Documents/my-new-app/ && cd ~/Documents/my-new-app && git init -b main` — same outcome.)

---

## Step 2 — Initialize the Flutter project on top

The template carries no native code, no `pubspec.yaml`, no platform folders. Generate them with the Flutter CLI:

```bash
# From inside the new project dir.
# This generates pubspec.yaml, android/, ios/, web/, macos/, windows/ and a default
# lib/main.dart (the default main.dart will be replaced in Step 6).
flutter create . --org com.daki.<projectname> --platforms=ios,android,web,macos,windows
```

Build hosts: macOS and iOS need a Mac, Windows needs Windows (or the `windows_release` CI workflow), web and Android build anywhere. Drop a platform from `--platforms` if you will not ship it.

Firebase caveat: `firebase_auth` is beta on macOS and Windows (Google: Windows is "not intended for production use cases"), and `firebase_messaging` has no Windows support. Guard push code with `defaultTargetPlatform`.

Then add the canonical deps from the master spec, grouped logically:

```bash
# Firebase — Auth + push only (no Firestore, no Functions)
flutter pub add firebase_core firebase_auth firebase_messaging

# Worker API client
flutter pub add http

# State management (Riverpod codegen)
flutter pub add flutter_riverpod riverpod_annotation

# Models (freezed + JSON)
flutter pub add freezed_annotation json_annotation

# Routing (go_router typed routes)
flutter pub add go_router

# UI
flutter pub add google_fonts lucide_icons flutter_animate

# Observability + analytics
flutter pub add sentry_flutter posthog_flutter

# Config
flutter pub add flutter_dotenv

# Dev dependencies — codegen + lint + test
flutter pub add --dev build_runner freezed json_serializable \
  riverpod_generator riverpod_lint custom_lint go_router_builder \
  mocktail very_good_analysis flutter_launcher_icons flutter_native_splash

# Integration tests (SDK-provided — manual add to pubspec dev_dependencies)
# integration_test:
#   sdk: flutter
```

Pin versions to those in the master spec (`docs/MASTER-SPEC.md` or the build context). Pin the Flutter SDK in `.fvmrc` to match CI.

Enable strict lints by setting `analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

---

## Step 3 — Fill in the placeholders

The template uses `{{PROJECT_NAME}}` and other markers. Run a quick find/replace in your editor:

| Placeholder | What to put |
|---|---|
| `{{PROJECT_NAME}}` | Your project's display name |
| `{{ONE_LINE_PITCH}}` | One sentence — what it does |
| `{{WHY}}` | One paragraph — why it exists |
| `{{DIFFERENTIATOR}}` | One sentence — what makes it different |
| `{{DATE}}` | Today's date |
| `{{N}}` (in PRD constraints) | Number of weeks budgeted |
| `{{PROJECT_SLUG}}` | lowercase-dashed name for the Worker + D1 database (`rust/api/wrangler.toml`) |
| `{{FIREBASE_PROJECT_ID}}` | Firebase project id — filled in Step 5 (`rust/api/wrangler.toml`) |
| `{{D1_DATABASE_ID}}` | printed by `wrangler d1 create` — filled in Step 7 (`rust/api/wrangler.toml`) |

Files that need editing:
- `CLAUDE.md`
- `docs/PRD.md`
- `docs/DESIGN.md`
- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/RELEASE.md`
- `docs/STORE_METADATA.md`
- `docs/legal/privacy.md`
- `docs/legal/terms.md`
- `rust/api/wrangler.toml`

A one-liner that does most of the work (replace `MyApp` first):
```bash
PROJECT_NAME="MyApp" grep -rl "{{PROJECT_NAME}}" . --exclude-dir=.dart_tool --exclude-dir=build \
  | xargs sed -i "" "s/{{PROJECT_NAME}}/$PROJECT_NAME/g"
```

---

## Step 3.5 — Pick a design system

The template ships with three pre-built design systems under [`design-systems/`](design-systems/). All three are cross-platform (iOS + Android). Pick one based on your project's vibe:

| System | Vibe | Best for |
|---|---|---|
| `notion-github` | Calm, data-dense | Trackers, productivity |
| `linear-minimal` | Sharp, monochrome | SaaS tools, dev apps |
| `warm-playful` | Soft, rounded | Consumer, wellness, habit, journal |

Read [`design-systems/README.md`](design-systems/README.md) and inspect each `mood.svg` before deciding. When torn, default to `notion-github` — most neutral and ages best.

Run the picker:

```bash
./scripts/pick-design-system.sh notion-github       # or linear-minimal / warm-playful
```

The script:
1. Copies the chosen `tokens.dart` → `lib/core/design/tokens.dart`
2. Copies the chosen `theme.dart` → `lib/core/design/theme.dart`
3. Copies the chosen `DESIGN.md` → `docs/DESIGN.md`
4. Removes the `design-systems/` folder (the final project carries only its chosen system)

After running:
- Wire `buildTheme(Brightness)` from `lib/core/design/theme.dart` into `MaterialApp.router` (already done in the Step 6 snippet below).
- Configure `google_fonts` for the system's typography (Inter / Nunito / JetBrains Mono).
- Review `docs/DESIGN.md` and tweak colors/values for your brand if needed.

**Switching later is expensive.** If you've built >3 screens and want to change, expect a 1–2 day swap. Pick deliberately the first time.

---

## Step 4 — Define your pillars in `docs/PRD.md`

Open `docs/PRD.md` and replace the pillar placeholders with 2–4 *actual* pillars for your product. **This is the most important step.** Every future feature will be scored against these pillars by `/spec` (strategist hat) and `/scope-check`. If the pillars are vague, the gatekeeping is vague.

A good pillar:
- Is one sentence.
- Names a user outcome, not a feature.
- Is in tension with the others (so you have to choose).

A bad pillar:
- "Be easy to use." (Every app says this.)
- "Push notifications." (That's a feature, not an outcome.)

---

## Step 5 — Set up Firebase (Auth only)

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication** (start with Anonymous; add Email/Password and OAuth later). Avoid SMS/phone sign-in — it is billed per message and is the largest cost line at scale.
3. Do **not** create a Firestore database or enable Functions/Storage — this stack does not use them.
4. Install the FlutterFire CLI and configure your app — this generates `lib/firebase_options.dart` for every platform:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

`lib/firebase_options.dart` is **committed**. It contains the public web API key, but it is not a secret — security comes from the Worker verifying the Firebase ID token on every request.

5. Put the Firebase project id into `rust/api/wrangler.toml` → `[vars] FIREBASE_PROJECT_ID`. The Worker rejects every request until it is set.

6. Copy non-secret runtime config into `.env`:

```bash
cp .env.example .env
# Edit .env with API_BASE_URL (Step 7), POSTHOG_KEY, SENTRY_DSN, etc.
```

---

## Step 5.5 — Integrate the Rust bridge

The template ships `rust/shared/` and one source file for the app-side crate (`rust/core/src/api/feedback.rs`). The crate around it is created by flutter_rust_bridge:

```bash
# Rust targets for mobile, macOS + the Worker
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios \
  aarch64-linux-android armv7-linux-androideabi x86_64-linux-android \
  aarch64-apple-darwin x86_64-apple-darwin wasm32-unknown-unknown
# Windows host only: rustup target add x86_64-pc-windows-msvc
# (needs Visual Studio "Desktop development with C++" — also required by Flutter on Windows)

cargo install flutter_rust_bridge_codegen

# From the project root. Creates the Rust crate, rust_builder/, and
# flutter_rust_bridge.yaml, and adds the Dart dependency.
flutter_rust_bridge_codegen integrate --rust-crate-dir rust/core
```

If your codegen version has no `--rust-crate-dir` flag (check `flutter_rust_bridge_codegen integrate --help`): move `rust/core/src/api/feedback.rs` aside, run plain `integrate`, move the generated crate from `rust/` to `rust/core/` without overwriting `rust/Cargo.toml`, `rust/shared/` or `rust/api/`, put `feedback.rs` back, and set `rust_root: rust/core/` in `flutter_rust_bridge.yaml`.

Then wire the shipped code into the generated crate:

1. `rust/core/Cargo.toml` → add under `[dependencies]`:
   ```toml
   shared = { path = "../shared" }
   serde_json = "1"
   ```
2. `rust/core/src/api/mod.rs` → add `pub mod feedback;` (you can delete the generated `simple.rs` and its `pub mod simple;`).
3. Generate the Dart bindings and run the Rust tests:
   ```bash
   flutter_rust_bridge_codegen generate
   (cd rust && cargo test)          # shared validation rules
   (cd rust/core && cargo test)     # payload builders
   ```

`lib/src/rust/` now contains `api/feedback.dart` with `buildFeedbackPayload(...)`, which `lib/features/feedback/feedback_provider.dart` already calls.

### Desktop (macOS, Windows)

`flutter run -d macos` / `-d windows` builds the Rust crate like mobile. macOS only: the sandbox blocks outgoing network by default. Add to **both** `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Without it every API call fails on macOS while working on iOS.

### Web

The web build runs the Rust crate as wasm with threads. One-time toolchain:

```bash
rustup toolchain install nightly
rustup +nightly component add rust-src
rustup +nightly target add wasm32-unknown-unknown
cargo install wasm-pack
```

Build and serve (sets the headers for you in dev):

```bash
flutter_rust_bridge_codegen build-web      # compiles rust/core to wasm into web/pkg
dart run flutter_rust_bridge:serve         # use instead of `flutter run -d chrome`
```

**Production hosting must send** `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, or the wasm module fails to start. Set them in your host's header config (Cloudflare Pages `_headers`, Firebase Hosting `headers`). **The template Worker has no CORS handling yet** (`rust/api/src` has none): a browser blocks every call, including the preflight, until the Worker answers `OPTIONS` and adds `Access-Control-Allow-Origin` / `-Headers: authorization, content-type`. Add it in `rust/api` before shipping web. `rust/core` stays `dart:io`-free and filesystem-free, which wasm needs — keep it that way.

---

## Step 6 — Replace `lib/main.dart`

`flutter create` writes a counter-demo `lib/main.dart`. Replace it with the bootstrap below, which wires the Rust library, Firebase, dotenv, PostHog, Sentry, ProviderScope, and `MaterialApp.router`:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:{{project_name}}/app.dart';
import 'package:{{project_name}}/firebase_options.dart';
import 'package:{{project_name}}/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(); // loads the compiled rust/core library
  await dotenv.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // PostHog (Step 6.5 wires the rest in lib/core/analytics/client.dart)
  final posthogKey = dotenv.env['POSTHOG_KEY'];
  if (posthogKey != null && posthogKey.isNotEmpty) {
    final config = PostHogConfig(posthogKey)
      ..host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com'
      ..captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
  }

  final sentryDsn = dotenv.env['SENTRY_DSN'];
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn ?? '';
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(const ProviderScope(child: App())),
  );
}
```

The backend client is already in the template (`lib/core/api/api_client.dart`) — nothing to copy. Scaffold your first data slice with `/d1`:

```bash
# Inside Claude Code in the project dir
/d1 profiles display_name:string handle:string
```

This writes the D1 migration, the `rust/shared` model + validation + tests, the Worker routes, and the `rust/core` payload builder, following the feedback reference slice.

---

## Step 6.5 — Wire the analytics provider

The template ships an analytics layer at [`lib/core/analytics/`](lib/core/analytics/) but the PostHog wiring is commented out by default. Open `lib/core/analytics/client.dart` and uncomment the PostHog lines — the wrapper signatures (`track`, `identify`, `reset`) don't change, only the bodies.

Default recommendation: **PostHog** (free tier ~1M events/month, covers MVP).

Create the PostHog project at https://posthog.com → grab the project API key → set it in `.env`:

```
POSTHOG_KEY=<your_key>
POSTHOG_HOST=https://us.i.posthog.com
SENTRY_DSN=<your_sentry_dsn>
```

Then write your North-Star Metric into `docs/TRACKING-PLAN.md` § NSM before adding any events. **No event gets added until the NSM is defined.**

Crash reporting via Sentry is wired separately in `main.dart` (Step 6) — analytics + crashes are different concerns.

---

## Step 7 — Run and deploy the API (Worker + D1)

All commands from `rust/api/`.

```bash
cd rust/api
npx wrangler login

# Create the database, then paste the printed id into wrangler.toml → database_id
npx wrangler d1 create <project-slug>

# Local: apply migrations to a local D1 and start the Worker on :8787
npx wrangler d1 migrations apply DB --local
npx wrangler dev
```

Smoke-test locally (second terminal):

```bash
curl http://localhost:8787/health                                  # → ok
curl -i -X POST http://localhost:8787/v1/feedback -d '{}'          # → 401 (no token)
```

Set `API_BASE_URL=http://localhost:8787` in `.env` (Android emulator: `http://10.0.2.2:8787`; web needs CORS on the Worker, see Step 5.5), run the app, submit feedback, then check the row:

```bash
npx wrangler d1 execute DB --local --command "SELECT * FROM feedback"
```

Deploy:

```bash
npx wrangler d1 migrations apply DB --remote
npx wrangler deploy          # prints the workers.dev URL → use it as API_BASE_URL for release builds
```

---

## Step 8 — Write your first PRD entry

```bash
# Inside Claude Code
/spec sign-in — Email/password auth with anonymous-account linking
```

`/spec` (strategist hat) will write the entry under the matching pillar. Iterate until you're happy.

---

## Step 9 — Run the development loop

The workflow is strict and the slash commands enforce it:

```
/spec    →  /design   →  /build   →  /test   →  /release
```

Each command runs in the main loop as a role "hat" (except `/test`, which spawns the `qa-engineer` sub-agent). Each phase's output is the next phase's input. **Don't skip.**

When you're not sure where to pick up:

```bash
/next        # one-line recommendation
git status   # what's in the working tree
```

Run codegen in a watcher during dev:

```bash
dart run build_runner watch -d
```

---

## Step 10 — Configure git

```bash
git init
git add .
git commit -m "Initial scaffolding from project template"
```

Add a remote when you have one.

---

## What's intentionally NOT in this template

- **`pubspec.yaml`** — generated by `flutter create` in Step 2.
- **`android/`, `ios/`, `web/`, `macos/`, `windows/` folders** — generated by `flutter create`. You edit them per project (bundle ID, signing, icons).
- **`lib/main.dart`** — `flutter create` writes a demo; you replace it with the Step 6 snippet.
- **`lib/firebase_options.dart`** — generated by `flutterfire configure` in Step 5. Committed once generated.
- **`rust/core/Cargo.toml`, `rust/core/src/lib.rs`, `rust_builder/`, `lib/src/rust/`** — created by flutter_rust_bridge in Step 5.5. Only `rust/core/src/api/feedback.rs` ships with the template.
- **`lib/core/design/tokens.dart` + `theme.dart`** — picked from the design-system family in Step 3.5, not pre-included.
- **`lib/core/analytics/client.dart` provider body** — PostHog wiring stays commented until you supply the key in Step 6.5.
- **R2 file uploads, realtime (Durable Objects), offline cache, queues** — not scaffolded. Add when a PRD feature needs one.
- **Rust steps in `codemagic.yaml`** — CI does not build the Rust crate yet; see the note at the top of that file.

This keeps the template small and avoids stale boilerplate. The Claude config + docs are the durable parts; the code scaffolding stays specific to each project.

---

## Token-saving setup verification

Before you start serious work, verify the token discipline is in place:

1. Open Claude Code in the project dir.
2. Type `/help` — you should see all slash commands listed.
3. Type `/scope-check coffee tracker` — should return a 3-line verdict.

If both work, the template is wired correctly.
