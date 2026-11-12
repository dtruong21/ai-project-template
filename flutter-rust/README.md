# Project Template — Flutter + Rust + Cloudflare

A starting point for solo-built mobile MVPs. Ships the Claude Code config, docs scaffolding, and a strict development workflow optimized for **token efficiency** and **QA quality**.

**Stack:** Flutter UI + Rust logic (flutter_rust_bridge) + Rust API on Cloudflare Workers + D1 + R2. Firebase kept for Auth and push only. Riverpod (AsyncNotifier) + go_router + freezed + Material 3.

> **Status (2026-11-12): backend verified locally, app integration not yet.** Verified with cargo 1.100, worker 0.9, jsonwebtoken 11, flutter_rust_bridge 2.13, wrangler 4.161: `rust/shared` and `rust/core` tests pass; `rust/api` builds to wasm (~865 KB) and, run under `wrangler dev` with a local D1, accepts a correctly signed token and rejects missing, malformed, expired, wrong-audience, wrong-issuer and tampered ones. **Not verified:** SETUP Step 5.5 (`flutter_rust_bridge_codegen integrate` on a real Flutter project), the Flutter app building and calling the API, token verification against Google's live keys, and `wrangler deploy`. Update this note after your first full setup.

---

## What this template gives you

| Layer | Content |
|---|---|
| **Claude config** | 7-role agent roster (idea-validator, product-strategist, ux-designer, developer, qa-engineer, release-manager, marketer) + 17 slash commands. Roles run **in the main loop as "hats"** (`docs/PRINCIPLES.md § Role hats`) by default — only `qa-engineer` spawns automatically; the rest are opt-in for big isolatable work. Tuned for Claude Pro usage limits. |
| **Workflow** | Strict idea → spec → design → build → test → release pipeline with handoff rules |
| **Design system family** | 3 cross-platform pre-built systems: `notion-github`, `linear-minimal`, `warm-playful`. Pick one per project during setup. |
| **Analytics layer** | Tracking plan (`docs/TRACKING-PLAN.md`) + typed event registry + provider-agnostic client. `/track` keeps the doc and types in sync. |
| **Feedback loop** | In-app feedback as the full reference slice: Rust validation → Worker route → D1 table + `feedback_submitted` event. |
| **Rust workspace** | `rust/shared` (models + validation, tested), `rust/api` (Worker: Firebase token check, D1), `rust/core` (app-side payload builders). `/d1` scaffolds new slices. |
| **Launch playbook** | Marketer hat + `LAUNCH.md` runbook + `/aso` + `/launch <channel>` commands. |
| **Solo-dev forcing functions** | `/weekly-review` Monday checkpoint, energy check, burnout flagging. |
| **Docs scaffolding** | PRD, Workflows, Tracking plan, Test plan, Roadmap, Release runbook, Launch playbook, Security, Store metadata, Legal templates |
| **QA emphasis** | Severity rubric, universal edge-case checklist, bug templates, pre-release gate |
| **Token discipline** | Commands run in the main loop as role "hats" — no per-phase sub-agent re-loading context (`docs/PRINCIPLES.md`) + constrained output formats |

---

## How to use it

Read [`SETUP.md`](SETUP.md) end-to-end. It walks you through copying the template, generating the Flutter project on top, filling placeholders, integrating the Rust bridge, and getting Cloudflare + Firebase Auth wired up.

Once instantiated, the development loop is:

```
/idea <business idea> → strategist hat validates it (GO/PIVOT/KILL)
/spec <feature>      → strategist hat writes the PRD entry
/design <screen>     → designer hat writes the screen spec
/build <feature>     → engineer hat implements it
/test <feature>      → qa-engineer AGENT writes tests + edge-case sweep
/release <channel>   → release hat cuts the build
```

All phases except `/test` run in the main loop. Plus micro-tasks (`/bug`, `/scope-check`, `/next`, `/qa-sweep`, `/weekly-review`), scaffolds (`/d1`, `/provider`, `/track`), and release/marketing (`/bump`, `/aso`, `/launch`).

Full slash-command index at [`.claude/commands/README.md`](.claude/commands/README.md).

---

## Design philosophy

- **Solo developer first.** No CODEOWNERS, no PR templates, no team rituals. Add them when you have a team.
- **Token efficiency for Claude Pro.** Routine phases run in the main loop as role "hats" — no per-phase sub-agent re-loading CLAUDE.md + a role file + docs. Only heavy QA (`/test`, `/qa-sweep`) spawns a sub-agent.
- **QA is the gate.** No release ships without a green run of the test plan.
- **Strict ordering.** Spec → Design → Build → Test. Skipping a step always costs more later.
- **One idiom per concern.** Riverpod (not Bloc + Provider + Riverpod). go_router_builder typed routes (not raw paths). freezed + json_serializable (not manual `fromJson`). Material 3 ThemeData (not custom inherited widgets).

---

## Why Rust + Cloudflare (and when not to)

Pick this stack over the plain `flutter/` one when run cost or footprint matters more than time-to-first-build:

- **Cost.** R2 has no egress fee, D1 and Workers bill per use with a $5/month base. Firebase's paid parts (Firestore reads, Storage egress, Functions) are gone.
- **One set of rules.** Validation and wire models are written once in `rust/shared` and run on both the phone and the server.
- **Small and fast backend.** A Worker scales to zero, has no cold-start container, and no server to patch.
- **Firebase stays where it is free.** Auth (email/social), FCM push, Crashlytics.

What you give up versus `flutter/`:

- **No client-to-database SDK.** Every feature needs an endpoint. More code per feature.
- **No built-in offline sync or realtime listeners.** Screens fetch on open and refresh. Realtime means Durable Objects — extra work.
- **Heavier toolchain.** cargo + mobile Rust targets + wrangler on top of Flutter; Rust changes need codegen and a full restart, not hot reload.

If the app is chat-like, offline-first, or you want the fastest possible MVP, use `../flutter/` instead. To measure whether this stack actually pays off for your app, follow `docs/BENCHMARK.md`.

---

## File layout

```
.claude/
  agents/          7 role agents (idea-validator → marketer) — only qa-engineer spawns by default
  commands/        17 slash commands (workflow + micro-tasks + scaffolds + marketing)
design-systems/    3 pre-built systems (pick one in SETUP.md Step 3.5)
  notion-github/   tokens.dart + theme.dart + DESIGN.md + mood.svg
  linear-minimal/  ...
  warm-playful/    ...
  README.md        which-to-pick guide
docs/
  PRD.md           Product requirements (pillars + feature specs)
  PRINCIPLES.md    Standing rules (MVP/UX/analytics/QA/security) + role "hats"
  WORKFLOWS.md     5-phase main-loop flow + 5 workflows
  TRACKING-PLAN.md Analytics PRD (events, properties, metrics, privacy)
  TEST-PLAN.md     QA checklist (universal + per-feature)
  ROADMAP.md       Phase status
  RELEASE.md       10-step release runbook (cutting builds)
  LAUNCH.md        Launch playbook (T-4w → T+7d, Product Hunt + tweet + email + community)
  SECURITY.md      Threat model + secrets policy
  BENCHMARK.md     How to measure this stack against the Firebase one
  STORE_METADATA.md  App Store + Play Store copy
  weekly-reviews/  output dir for /weekly-review
  legal/           Privacy + Terms boilerplate
  bugs/            Active bug reports (auto-filled by /bug)
    closed/        Closed bugs archive
  (DESIGN.md is created from the chosen design-system at setup)
lib/
  core/
    analytics/     client.dart + events.dart (typed event registry) + README
    api/           api_client.dart + api_exception.dart + contract README
    design/        (tokens.dart + theme.dart from chosen design-system)
    routing/       router.dart + routes.dart (typed go_router)
  features/
    feedback/      feedback notifier + pattern README
  src/rust/        GENERATED by flutter_rust_bridge (never hand-edit)
rust/
  Cargo.toml       workspace (shared + api)
  shared/          models + validation — used by core and api
  core/            app-side Rust exposed to Dart (crate created in SETUP Step 5)
  api/             Cloudflare Worker — src/, migrations/, wrangler.toml
integration_test/  E2E golden-path flows
scripts/
  pick-design-system.sh   one-shot picker (Step 3.5)
.fvmrc             Flutter SDK pin
analysis_options.yaml   very_good_analysis + custom_lint
codemagic.yaml     CI workflows
CLAUDE.md          Claude constitution — loaded every session
SETUP.md           Bootstrap guide (read first)
README.md          This file
```

---

## When to update the template itself

This template is meant to evolve. After you ship a project and notice a pattern that worked (or one that bit you), come back and:

- Add a new slash command if you typed the same prompt 3+ times
- Add a new edge case to `docs/TEST-PLAN.md` § Universal if a bug bit two different projects
- Refine a command's prompt (or a role hat in `docs/PRINCIPLES.md`) if it kept making the same wrong choice

The template is the accumulated lesson. Update it.

---

## Sibling templates

Same workflow, same main-loop "hats", same docs structure, different stack — all in https://github.com/dtruong21/ai-project-template :

- **`flutter/`** — Flutter + Firebase (Firestore, Functions). Fastest path to an MVP; offline sync and realtime built in.
- **`react-native/`** — Expo + Firebase. JS ecosystem, web parity.

The role "hats", the 7-role agent roster, and the `/idea → /spec → /design → /build → /test → /release` workflow are shared, so cross-referencing patterns between them is cheap. Only the data layer differs: here it is `/d1` + Worker routes instead of `/firestore` + security rules.
