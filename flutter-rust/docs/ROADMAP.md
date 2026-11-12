# {{PROJECT_NAME}} — Roadmap

Updated **{{DATE}}** — reflects actual state, not the original plan.

> **v1 = MVP, no exceptions.** This roadmap covers what ships in v1 (the minimum across all pillars) and what's deferred to v1.1+. If you find yourself adding "just one more thing" to v1, it goes under § Intentionally deferred instead.

## Status legend

- ✅ Shipped
- 🚧 In progress
- ⏳ Up next (committed)
- ⏸️ Deferred (post-MVP candidate)
- ❌ Not started

---

## Phase 0 — Foundation ❌

Boots, signs in, persists, instrumented.

- ❌ Flutter (pinned via `.fvmrc`) + Dart strict (`very_good_analysis`) + go_router (typed routes via `go_router_builder`)
- ❌ Material 3 theme wired from chosen design system (`lib/core/design/tokens.dart` + `theme.dart`)
- ❌ FlutterFire: Auth (anonymous). Worker deployed (`rust/api`), D1 migrations applied, `/health` answers
- ❌ flutter_rust_bridge integrated — `rust/core` builds for iOS + Android, `lib/src/rust/` generated
- ❌ Analytics provider wired (Firebase Analytics + PostHog) — `lib/core/analytics/client.dart` calls real SDKs
- ❌ NSM + initial events defined in `docs/TRACKING-PLAN.md` and typed in `lib/core/analytics/events.dart`
- ❌ Sentry (`sentry_flutter`) for crash + perf reporting
- ❌ In-app feedback path (`lib/features/feedback/`) writes to D1 via the Worker (Rust-validated payload)
- ❌ CI: `flutter analyze` + `flutter test` on PR (Codemagic)

**Exit:** App boots in simulator, anon sign-in works, all data persists across restarts, `app_opened` event arrives in the analytics dashboard, feedback submission round-trips to D1.

---

## Phase 1 — {{Core loop}} ❌

{{One-line summary of the pillar this phase ships.}}

- ❌ {{Feature 1}}
- ❌ {{Feature 2}}

**Exit:** {{What "done" looks like for this phase.}}

---

## Phase 2 — {{Pillar 2}} ❌

- ❌ {{Feature 1}}

---

## Phase 3 — {{Pillar 3}} ❌

- ❌ {{Feature 1}}

---

## Phase N — Polish + submit ❌

Launch-ready.

- ❌ Privacy policy + Terms of Service (host the markdown from `docs/legal/` publicly)
- ❌ Store screenshots (5 per platform from real builds)
- ❌ App Store + Play Store metadata
- ❌ Production Codemagic build + submit
- ❌ Real-device smoke test

---

## Critical path to first release

| Week | Goal |
|------|------|
| Week 1 | Phase 0 |
| Week 2 | Phase 1 |
| Week 3 | Phase 2 |
| Week 4 | Phase 3 |
| Week 5–6 | Phase N — polish, store assets, submit |

## Slip absorber

If a phase slips, **{{cut-first pillar}}** is the first to drop. Ship N pillars well rather than N+1 poorly. Document the cut in `docs/PRD.md § Out of scope`.

## Intentionally deferred (post-MVP)

Cuts from the original plan. Track here so they don't sneak back in:

- {{Cut 1}}
- {{Cut 2}}

## Tracking per-feature spec status

`/spec` writes a PRD entry → `docs/PRD.md` is the source of truth for what each feature does. The phase checklist here only tracks *whether* a feature has shipped; *what* it does is in PRD.
