# Project Template — Firebase Mobile (Flutter)

A starting point for solo-built mobile MVPs. Ships the Claude Code config, docs scaffolding, and a strict development workflow optimized for **token efficiency** and **QA quality**.

**Stack:** Flutter + Firebase (Auth, Firestore, Functions) + Riverpod (AsyncNotifier) + go_router + freezed + Material 3.

---

## What this template gives you

| Layer | Content |
|---|---|
| **Claude config** | 7-role agent roster (idea-validator, product-strategist, ux-designer, developer, qa-engineer, release-manager, marketer) + 17 slash commands. Roles run **in the main loop as "hats"** (`docs/PRINCIPLES.md § Role hats`) by default — only `qa-engineer` spawns automatically; the rest are opt-in for big isolatable work. Tuned for Claude Pro usage limits. |
| **Workflow** | Strict idea → spec → design → build → test → release pipeline with handoff rules |
| **Design system family** | 3 cross-platform pre-built systems: `notion-github`, `linear-minimal`, `warm-playful`. Pick one per project during setup. |
| **Analytics layer** | Tracking plan (`docs/TRACKING-PLAN.md`) + typed event registry + provider-agnostic client. `/track` keeps the doc and types in sync. |
| **Feedback loop** | In-app feedback notifier + Firestore pattern + `feedback_submitted` event baked in. |
| **Launch playbook** | Marketer hat + `LAUNCH.md` runbook + `/aso` + `/launch <channel>` commands. |
| **Solo-dev forcing functions** | `/weekly-review` Monday checkpoint, energy check, burnout flagging. |
| **Docs scaffolding** | PRD, Workflows, Tracking plan, Test plan, Roadmap, Release runbook, Launch playbook, Security, Store metadata, Legal templates |
| **QA emphasis** | Severity rubric, universal edge-case checklist, bug templates, pre-release gate |
| **Token discipline** | Commands run in the main loop as role "hats" — no per-phase sub-agent re-loading context (`docs/PRINCIPLES.md`) + constrained output formats |

---

## How to use it

Read [`SETUP.md`](SETUP.md) end-to-end. It walks you through copying the template, generating the Flutter project on top, filling placeholders, and getting Firebase wired up.

Once instantiated, the development loop is:

```
/idea <business idea> → strategist hat validates it (GO/PIVOT/KILL)
/spec <feature>      → strategist hat writes the PRD entry
/design <screen>     → designer hat writes the screen spec
/build <feature>     → engineer hat implements it
/test <feature>      → qa-engineer AGENT writes tests + edge-case sweep
/release <channel>   → release hat cuts the build
```

All phases except `/test` run in the main loop. Plus micro-tasks (`/bug`, `/scope-check`, `/next`, `/qa-sweep`, `/weekly-review`), scaffolds (`/firestore`, `/provider`, `/track`), and release/marketing (`/bump`, `/aso`, `/launch`).

Full slash-command index at [`.claude/commands/README.md`](.claude/commands/README.md).

---

## Design philosophy

- **Solo developer first.** No CODEOWNERS, no PR templates, no team rituals. Add them when you have a team.
- **Token efficiency for Claude Pro.** Routine phases run in the main loop as role "hats" — no per-phase sub-agent re-loading CLAUDE.md + a role file + docs. Only heavy QA (`/test`, `/qa-sweep`) spawns a sub-agent.
- **QA is the gate.** No release ships without a green run of the test plan.
- **Strict ordering.** Spec → Design → Build → Test. Skipping a step always costs more later.
- **One idiom per concern.** Riverpod (not Bloc + Provider + Riverpod). go_router_builder typed routes (not raw paths). freezed + json_serializable (not manual `fromJson`). Material 3 ThemeData (not custom inherited widgets).

---

## Why Firebase

The template is intentionally Firebase-only because:

- **Security model is well-understood.** Rules + Auth + App Check replace 90% of what a custom backend would do.
- **Free tier supports MVPs.** Most projects ship to TestFlight before paying anything.
- **Cloud Functions cover the gaps.** When the client can't (cascade-deletes, server-side validation), Functions do.
- **One vendor, one mental model.** Auth state, data persistence, and compute share an identity.
- **FlutterFire is first-party.** Codegen-generated `firebase_options.dart`, official plugins, no community bridging.

If you're considering a different backend (Supabase, custom Dart server, etc.), this template is not the right starting point — fork and adapt, or use a different template.

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
  STORE_METADATA.md  App Store + Play Store copy
  weekly-reviews/  output dir for /weekly-review
  legal/           Privacy + Terms boilerplate
  bugs/            Active bug reports (auto-filled by /bug)
    closed/        Closed bugs archive
  (DESIGN.md is created from the chosen design-system at setup)
lib/
  core/
    analytics/     client.dart + events.dart (typed event registry) + README
    firebase/      (repositories scaffolded by /firestore)
    design/        (tokens.dart + theme.dart from chosen design-system)
    routing/       router.dart + routes.dart (typed go_router)
  features/
    feedback/      feedback notifier + pattern README
firebase/
  firestore.rules
  firestore.indexes.json
  functions/       Cloud Functions (TypeScript)
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

This template has a React Native sibling — same workflow, same main-loop "hats", same docs structure, different stack:

- **React Native (Expo) version:** https://github.com/dtruong21/ai-project-template

Use the RN sibling for projects where rapid web parity, JS-ecosystem tooling, or existing React skills tip the trade-off. Use this Flutter template for projects where native UI fidelity, strict typing through the data layer (freezed), and Material 3 are the better fit.

Both templates share the same Firebase model, the same role "hats" + 7-role agent roster (with stack-specific deltas), and the same `/idea → /spec → /design → /build → /test → /release` workflow — so cross-referencing patterns between them is cheap.
