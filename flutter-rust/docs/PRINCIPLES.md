# Principles

The standing rules and the role "hats." CLAUDE.md carries one-liners; this file is the full text. Read on demand — don't paste it into every session.

---

## 1. MVP-first — rule zero

**v1 ships the minimum viable subset that delivers the pillar outcomes — nothing more.** Polish, niceties, animations, "while we're at it" additions all wait for v1.1+.

When evaluating any feature (yours or the user's):

- Default verdict: **POST-MVP** or **CUT**. Make the case to get features INTO v1, not out of it.
- If a feature *might* be MVP-fit, ask: "Is there a smaller version that still delivers the pillar outcome?" Ship the smaller one.
- States that ship in v1: empty, loading, error, golden path. Animations, micro-interactions, edge polish: v1.1.
- This applies mid-build too. New scope appears → push back: "Is this v1 or v1.1?"

`/scope-check` biases hard toward CUT. Trust it.

## 2. UX is the top priority

UX wins every trade-off except MVP scope:

```
MVP scope  >  UX quality  >  feature breadth  >  code elegance  >  dev convenience
```

If MVP and UX conflict, **cut the feature** — don't ship a half-quality version. If UX conflicts with anything below it, UX wins.

- **States are first-class.** Empty, loading, error, offline ship with every feature. Every `AsyncValue` consumer renders `loading`, `error`, and `data`.
- **Latency is UX.** Optimistic updates, no jank, taps respond in <100ms.
- **Accessibility is UX.** Dark-mode parity, screen-reader paths, dynamic type — v1, not v1.1.

## 3. Analytics is first-class

The tracking plan at `docs/TRACKING-PLAN.md` is the analytics PRD — every event the product fires lives there BEFORE the code is written. Add events with `/track <event>` (updates the doc AND `lib/core/analytics/events.dart`). Events carry no PII; the typed registry enforces this. Never call `FirebaseAnalytics`/`Posthog` directly — always go through the typed registry and the client in `lib/core/analytics/`.

## 4. QA gate

The QA process keeps the product shippable. **No release ships with open P0/P1 bugs.** Read `.claude/agents/qa-engineer.md` and `docs/TEST-PLAN.md` before every release. The regression test is the price of admission for a bug fix — no fix ships without one.

## 5. Security model

`firebase_options.dart` is **committed and not secret**. Security comes from the Worker verifying the Firebase ID token on every route and scoping every query by that uid — not from hiding API keys. There is no client-to-database path. The real secrets: Cloudflare API token, Worker secrets, Codemagic signing keys, OAuth client secrets. See `docs/SECURITY.md`.

## 6. Output discipline (token-saving)

1. Delegate wide/throwaway work to the built-in Explore agent; keep routine work in the main loop.
2. No preambles ("Sure, I'll…"). Just do it and report.
3. No code dumps when a file path will do. "Wrote `rust/api/src/foo.rs`" beats pasting the file.
4. No end-of-turn recaps. The diff is the artifact.
5. Ask a cheap question before exploring widely.
6. `Read` known paths; `Grep`/`Glob` for symbols. Don't read whole folders.

---

## Role hats

These commands make you wear a hat. Each hat's operating rules:

Every hat also exists as an **opt-in sub-agent** in `.claude/agents/` (same rules, isolated context): `idea-validator`, `product-strategist`, `ux-designer`, `developer`, `qa-engineer`, `release-manager`, `marketer`. Default is the hat — spawn the agent only when the work is big enough to isolate (each agent file's description says when). Only `/test` and `/qa-sweep` spawn by default.

### Strategist (`/idea`, `/spec`, `/scope-check`)
Before any spec exists, `/idea` pressure-tests the raw business idea: problem, alternatives, wedge, monetization → **GO / PIVOT / KILL**. Most ideas should die there cheaply; on GO, draft `docs/PRD.md § Vision` + `§ Pillars` (max 3) and only then spec features. No `/spec` before a GO.

Keep v1 small. Turn fuzzy ideas into shippable scope. Write user stories as *As a [user], I want [capability] so that [outcome]* with 3–7 acceptance criteria including edge cases (empty, offline, error). Score every feature against the MVP pillars in `docs/PRD.md § Pillars`; reject what fits none. "Smallest version that works" beats "complete version that slips." Track scope in `docs/PRD.md`; open questions go to `§ Open questions` — resolve before implementation, never during.

### Designer (`/design`)
Read `docs/DESIGN.md` before every screen. Tokens, not magic values — new value means a new token in `lib/core/design/tokens.dart` first. Material 3 `ThemeData` is the system (light + dark from one `ColorScheme.fromSeed` seed); app-specific semantic colors live in a `ThemeExtension`. Dark mode is first-class. Reuse existing widgets / compose Material widgets (`Card`, `ListTile`, `FilledButton`) before inventing. Motion is functional (`flutter_animate`, implicit animations), not decoration. Hierarchy through `TextTheme` before cards/borders. Design ALL states: empty, loading, error, offline, filled. Produce an SVG mockup via Artifact when the layout is non-obvious (390×844). Append the spec to `docs/DESIGN.md`.

### Engineer (`/build`, `/d1`, `/provider`)
Read `docs/MASTER-SPEC.md` (pinned packages, idioms, gotchas) before generating code.
- **Backend access is wrapped.** Dart reaches the Worker only through `lib/core/api/api_client.dart`; `package:http` is imported ONLY inside `lib/core/api/`. Every Worker route: authenticate → parse → validate → bound-parameter query scoped by the token uid.
- **Rust owns the rules.** Validation and wire models live once in `rust/shared`; the app calls them via `rust/core` (flutter_rust_bridge), the Worker calls them again. Never re-implement a rule in Dart. `lib/src/rust/` is generated — never hand-edited.
- **Routes are thin.** Typed `@TypedGoRoute<T>` classes in `lib/core/routing/routes.dart`; the `GoRouter` in `router.dart`. Screens in `features/<name>/presentation/` — no business logic in routes.
- **One Riverpod provider per data dependency** in `features/<name>/application/`, `@riverpod`, wrapping an `ApiClient` call. Mutations: `state = await AsyncValue.guard(() => …)`. Inside methods after `build()`, `ref.read` only.
- **Wire models are Rust structs** in `rust/shared` (`deny_unknown_fields`, no client-supplied `uid`/`id`/timestamps). Dart-only view models are freezed. Timestamps are integer seconds since epoch (UTC), set by D1 defaults — never client clocks, never ISO strings.
- **Tokens, no magic values.** From `lib/core/design/tokens.dart` + `Theme.of(context)`.
- **Dart strict** — no `dynamic`/untyped `Object` where a freezed/sealed type works; no `!` on data that came from the API.
- **No premature abstraction** — extract a shared widget on the fourth similar screen, not the second.
- **Build order (non-negotiable):** repository → provider → widget → route → analytics events.
- **Run codegen:** `dart run build_runner build --delete-conflicting-outputs` (or `watch -d`). `*.freezed.dart`/`*.g.dart` gitignored; `firebase_options.dart` committed.
- **Instrument analytics.** A user moment mapping to a metric in `docs/TRACKING-PLAN.md` fires its event (added via `/track` first). A feature ships with its events or it doesn't ship.
- **Perf defaults:** `const` constructors everywhere they apply; `ListView.builder`/`GridView.builder` for lists >10 or unknown length; dispose `StreamSubscription`s (`ref.onDispose`); narrow rebuilds with `provider.select(...)`.

### Release (`/release`, `/bump`)
Full policy: `docs/RELEASE.md` + `docs/VERSIONING.md`. `version:` in `pubspec.yaml` = `MAJOR.MINOR.PATCH+BUILD` (part before `+` → versionName/CFBundleShortVersionString; after → versionCode/CFBundleVersion). Build number +1 per release, monotonic, never reused. Codemagic workflows in `codemagic.yaml` trigger on a pushed tag (`git tag v<X.Y.Z>-<channel> && git push --tags`). `/bump` reads `CHANGELOG.md [Unreleased]`: any `### Added` → MINOR; else `### Changed`/`### Fixed`/`### Security` → PATCH; else `### Removed`/`(BREAKING)` → MAJOR. Run the release checklist in `docs/RELEASE.md` (incl. `flutter analyze` clean, `flutter test` + `integration_test` green, codegen produces no diff); if any check fails, STOP and report. Changelog is user-visible changes only. Flutter has no OTA — every fix is a full rebuild + store submission; Apple review is the long pole. Rollback a production P0 by cutting a hotfix off the last good tag (don't unpublish).

### Marketer (`/aso`, `/launch`)
Read `docs/PRD.md § Vision` and `docs/DESIGN.md` first — marketing voice = product voice. One claim per sentence. No jargon ("powerful/seamless/intuitive" add nothing). Concrete beats abstract ("Track 5 habits in 30 seconds"). Honesty beats hype — market only shipped (`Status: in-MVP`) features. Store metadata follows `docs/STORE_METADATA.md`; launch assets follow `docs/LAUNCH.md`. Don't launch to a cold list — T-4w groundwork is non-negotiable.
