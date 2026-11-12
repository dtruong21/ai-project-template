# Template setup — instantiate a new Flutter project

This template gives you the Claude config + docs scaffolding. You bring the actual Flutter project. The steps below are the one-time bootstrap to wire them together.

---

## Step 1 — Bootstrap a new project from this template

The Flutter template lives in the `flutter/` subdir of the multi-stack templates repo. Easiest way to start a new project:

```bash
# Once: clone the templates repo somewhere you can find it
git clone https://github.com/dtruong21/ai-project-template.git ~/Documents/templates

# Each new project: one command
~/Documents/templates/scripts/new-project.sh flutter ~/Documents/my-new-app

# Then drop this SETUP.md after you're done — it's not project content
cd ~/Documents/my-new-app
rm SETUP.md
```

The helper copies `flutter/` into the target dir (excluding `.git`) and initializes a fresh `git` repo on `main`.

(If you've already cloned the templates repo, you can manually `cp -R ~/Documents/templates/flutter/. ~/Documents/my-new-app/ && cd ~/Documents/my-new-app && git init -b main` — same outcome.)

---

## Step 2 — Initialize the Flutter project on top

The template carries no native code, no `pubspec.yaml`, no platform folders. Generate them with the Flutter CLI:

```bash
# From inside the new project dir.
# This generates pubspec.yaml, android/, ios/, and a default lib/main.dart
# (the default main.dart will be replaced in Step 6).
flutter create . --org com.daki.<projectname> --platforms=ios,android
```

Then add the canonical deps from the master spec, grouped logically:

```bash
# Firebase
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_analytics

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

## Step 5 — Set up Firebase

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication** (start with Anonymous; add Email/Password and OAuth later)
3. Create a **Firestore database** (start in test mode; the deploy in Step 7 swaps in real rules)
4. Install + sign in to the Firebase CLI:

```bash
npm install -g firebase-tools
firebase login
firebase use --add        # picks the project and writes .firebaserc
```

5. Install the FlutterFire CLI and configure your app — this generates `lib/firebase_options.dart` for every platform:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

`lib/firebase_options.dart` is **committed**. It contains the public web API key, but it is not a secret — security comes from Firestore rules + App Check.

6. Copy non-secret runtime config into `.env`:

```bash
cp .env.example .env
# Edit .env with POSTHOG_KEY, SENTRY_DSN, etc.
```

---

## Step 6 — Replace `lib/main.dart` and add the Firebase client

`flutter create` writes a counter-demo `lib/main.dart`. Replace it with the bootstrap below, which wires Firebase, dotenv, PostHog, Sentry, ProviderScope, and `MaterialApp.router`:

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

And the thin Firebase client (handles to `auth`, `db`, `functions` — repositories import from here):

```dart
// lib/core/firebase/firebase_client.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuth = FirebaseAuth.instance;
final firestore = FirebaseFirestore.instance;
final functions = FirebaseFunctions.instance;
```

Then scaffold your first collection wrapper with `/firestore`:

```bash
# Inside Claude Code in the project dir
/firestore users displayName:string handle:string createdAt:timestamp
```

This drops a typed repository at `lib/core/firebase/users_repository.dart` following the canonical `.withConverter` + freezed pattern.

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

## Step 7 — Deploy the starter Firestore rules

The template ships with a placeholder `firebase/firestore.rules` (you'll harden it as features ship). For the initial deploy:

```bash
firebase deploy --only firestore:rules
```

Test the rules in the Firebase Console → Firestore → Rules → Playground tab before deploying to production environments.

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
- **`android/`, `ios/`, `web/` folders** — generated by `flutter create`. You edit them per project (bundle ID, signing, icons).
- **`lib/main.dart`** — `flutter create` writes a demo; you replace it with the Step 6 snippet.
- **`lib/firebase_options.dart`** — generated by `flutterfire configure` in Step 5. Committed once generated.
- **`lib/core/firebase/firebase_client.dart`** — copy the snippet from Step 6.
- **`lib/core/design/tokens.dart` + `theme.dart`** — picked from the design-system family in Step 3.5, not pre-included.
- **`lib/core/analytics/client.dart` provider body** — PostHog wiring stays commented until you supply the key in Step 6.5.
- **`firebase/firestore.rules`** — placeholder only. Real rules ship as features ship.

This keeps the template small and avoids stale boilerplate. The Claude config + docs are the durable parts; the code scaffolding stays specific to each project.

---

## Token-saving setup verification

Before you start serious work, verify the token discipline is in place:

1. Open Claude Code in the project dir.
2. Type `/help` — you should see all slash commands listed.
3. Type `/scope-check coffee tracker` — should return a 3-line verdict.

If both work, the template is wired correctly.
