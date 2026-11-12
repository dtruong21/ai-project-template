# Test Plan

The canonical checklist `qa-engineer` runs before any release. Living document — grow it as features ship.

> **Rule:** No release ships without a green run of this plan on iOS Simulator + Android Emulator + at least one real device.

---

## How to use this file

1. Per feature, add a section under § Feature checklists. Use the template below.
2. Before each release, `qa-engineer` runs every box. Any fail → file a bug via `/bug`, link the slug back here.
3. Move features from "active" to "stable" once they've passed 3 consecutive releases with no regression bugs filed.

---

## Test categories (Flutter)

The pyramid for this template — write the cheap ones first, fall back to the expensive ones only when you must.

| Category | Tool | Runs in | When to use |
|---|---|---|---|
| **Unit** | `flutter_test` | Pure Dart | Notifier logic with a fake `apiClientProvider`, pure functions |
| **Rust unit** | `cargo test` (`rust/`, `rust/core/`) | Native | Validation rules in `shared`, payload builders in `core` |
| **API smoke** | `wrangler dev` + `curl` | Local Worker + local D1 | Auth (401), validation (422), cross-user access (404) |
| **Widget** | `flutter_test` + `ProviderScope` test harness (`test/helpers/pump_app.dart`) | Flutter test renderer | Single screen / widget behavior, state transitions, golden path of a feature |
| **Golden** | `flutter_test` (`matchesGoldenFile`) | Flutter test renderer | Visual regressions on key screens — run on one host platform only (CI matrix pinned) |
| **Integration** | `integration_test` package | Real simulator/emulator | End-to-end golden flows (sign-in, create-first-thing, etc.) |

**Rule:** Mocks via `mocktail` only. Register fallback values for non-primitive matchers in `setUpAll`. No codegen-based mocks.

---

## Universal edge cases (run for every release)

Failure modes that bite mobile + Firebase apps regardless of feature:

### Data + time

- [ ] Timezone math. Date-keyed data must respect local TZ, not UTC.
- [ ] Date rollover at midnight — "today" advances without manual refresh.
- [ ] DST transition — math still correct on clock-change days.
- [ ] Long strings (≥1000 chars) in text fields don't crash.
- [ ] Long lists (≥100 items) render without dropped frames.
- [ ] `Timestamp` → `DateTime` conversion uses the registered `JsonConverter` everywhere (no raw `.toDate()` calls leaking into models).

### Network

- [ ] Offline write queues (toggle airplane mode mid-action).
- [ ] Reconnect syncs queued writes.
- [ ] Slow network throttle (Network Link Conditioner / Android emulator throttle) doesn't break UI.
- [ ] Cold offline launch shows the offline state with retry — never a blank screen or infinite spinner. (No local cache by default; add one only if a pillar needs offline reads.)

### Desktop + web (macOS, Windows, browser)

- [ ] Resize the window from phone width to ultrawide — no overflow, no unreadable line lengths.
- [ ] Keyboard only: Tab order is sane, Enter submits forms, Esc closes dialogs, focus ring visible.
- [ ] Mouse hover and right-click do not break gestures designed for touch.
- [ ] macOS: API calls work in the Release build (`com.apple.security.network.client` entitlement present).
- [ ] Web: page loads with the real host's COOP/COEP headers — Rust (wasm) initializes, `crossOriginIsolated` is true.
- [ ] Web: browser refresh and Back/Forward keep the route and do not lose signed-in state.
- [ ] Web: first load over a throttled connection shows a loading state, not a blank page.
- [ ] Web: an API call from the deployed origin passes CORS (preflight answered).

### Auth

- [ ] Anonymous → real-account linking preserves uid + data.
- [ ] Sign-out clears all local state (Riverpod providers invalidated, in-memory caches dropped).
- [ ] Account deletion cascade leaves zero orphan docs.
- [ ] Token refresh works after 1h+ idle.

### Permissions

- [ ] Push notification permission denied — feature still works, nudges silently disabled.
- [ ] Camera/photo permission denied — graceful fallback.

### Lifecycle

- [ ] Cold start (after force-kill) reaches the right screen within 3s on mid-tier Android.
- [ ] Background → foreground after 10+ min doesn't crash or duplicate state.
- [ ] Deep link cold-opens app to the linked screen (go_router `initialLocation` path).

### Memory + perf

- [ ] 5 min of typical use → no obvious memory growth (DevTools memory tab).
- [ ] No request storms — a screen fetches once on open and on explicit refresh; no polling loops left running after the screen is disposed.

### Security

- [ ] API denies cross-user access: with user A's token, reading/updating/deleting user B's row id returns 404; with no token every `/v1/*` route returns 401.
- [ ] Every route in `rust/api/src/` calls `auth::uid_from_request` before touching D1, and every SQL statement uses bound parameters (`grep -n "format!" rust/api/src/` shows no SQL).
- [ ] `.env` is gitignored — `git log --all -p -- .env` returns nothing.
- [ ] No `package:http` imports outside `lib/core/api/` (`grep -r "package:http" lib/ --include="*.dart" | grep -v "lib/core/api"` returns nothing).

### Visual + a11y

- [ ] Dark mode parity for every shipped screen (both `ThemeMode.light` and `ThemeMode.dark`).
- [ ] Dynamic type at 200% (`MediaQueryData.textScaleFactor`) doesn't truncate critical text.
- [ ] Screen reader (VoiceOver / TalkBack) reaches every action — every interactive widget has a `Semantics` label or wraps a Material widget that provides one.

---

## Feature checklists

Add one section per shipped feature. Template:

### Feature: {{feature-name}}

Status: active | stable | retired
Related PRD entry: `docs/PRD.md § Feature: {{feature-name}}`

**Golden path:**
- [ ] {{step 1 + expected result}}
- [ ] {{step 2 + expected result}}

**Edge cases (specific to this feature):**
- [ ] {{edge case 1}}
- [ ] {{edge case 2}}

**Known issues:**
- {{link to active bug docs/bugs/<date>-<slug>.md if any}}

---

## Pre-release gate (must pass — no exceptions)

Before `/release` cuts a build:

- [ ] `flutter analyze` is clean (zero warnings)
- [ ] `flutter test` is green
- [ ] `flutter test integration_test` is green on iOS Simulator + Android Emulator
- [ ] Golden tests pass on the canonical host (no unintentional re-baselines)
- [ ] All universal edge cases pass on iOS + Android simulator
- [ ] All feature checklists for this release pass
- [ ] Zero open P0/P1 bugs (`docs/bugs/`)
- [ ] No new console warnings introduced this release
- [ ] Real-device smoke test (NOT simulator) on at least one device per platform
- [ ] Memory + perf check (DevTools — flat memory line, no jank > 16ms in steady state)
- [ ] Worker + D1 migrations deployed to the matching environment (`/health` answers, `wrangler d1 migrations list DB --remote` shows none pending)

---

## How to file a failure

When a checkbox doesn't pass:

1. Run `/bug <title> — <repro>` — files `docs/bugs/<YYYY-MM-DD>-<slug>.md`.
2. Link the bug slug under the relevant checklist item: `- [ ] {{step}} — see bug-<slug>`.
3. Don't uncheck other items just because one failed — keep the rest green so the team sees what *does* work.
