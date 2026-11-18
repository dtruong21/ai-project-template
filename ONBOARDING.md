# Onboarding — mobile MVP templates

This repo is a **multi-stack project template**, not a product. Pick a stack, scaffold a fresh app, ship a Firebase mobile MVP fast. Two stacks, one workflow shape:

| Subdir | Stack |
|---|---|
| [`react-native/`](react-native/) | React Native (Expo) + Firebase · Zustand + TanStack Query · NativeWind · EAS |
| [`flutter/`](flutter/) | Flutter + Firebase · Riverpod + go_router · Material 3 · Codemagic |

## Which mode are you in?

**A) Starting a new project** — you want an app, not to edit the template:
```bash
./scripts/new-project.sh react-native ~/Documents/my-app   # or: flutter
cd ~/Documents/my-app && cat SETUP.md                       # follow from Step 2
```
The helper copies the stack, detaches template git history, inits a fresh repo. **Don't skip SETUP Step 3.5** (`pick-design-system.sh`) — it generates `docs/DESIGN.md` from your chosen design system. Until you run it, `docs/DESIGN.md` won't exist (by design), and any command that references it can't resolve.

**B) Improving the template itself** — you're here to make the scaffold better:
```bash
cd react-native/   # or: cd flutter/
```
The full Claude Code setup activates inside the subdir. **If a change applies to both stacks, mirror it across both** — otherwise they drift.

## The mental model (read this — it's the recent change)

The template is **tuned for Claude Pro usage limits**. The rule that drives everything: *minimize total tokens, not just main-loop cleanliness.*

So routine work runs **in the main loop** by wearing a role "hat" — **not** by spawning a sub-agent per phase. A sub-agent is a fresh context that re-pays the whole tax (CLAUDE.md + role def + docs); on Pro that's expensive. The old design spawned one per phase; this one doesn't.

- **A full 8-role agent roster lives in `.claude/agents/`** (`flutter-rust` adds rust-backend, security-auditor, perf-auditor, devops) — idea-validator, product-strategist, product-owner, ux-designer, developer, qa-engineer, release-manager, marketer — but only **`qa-engineer` spawns by default** (`/test`, `/qa-sweep`; QA reads a lot, so isolation genuinely pays). The rest are **opt-in**: spawn one when the work is big enough to isolate (deep idea validation with web research, a whole-app design pass, a multi-feature build batch, a full launch-asset batch). Wide multi-file searches → the built-in **Explore** agent.
- **Everything else is a hat.** `/idea` `/spec` = strategist, `/design` = designer, `/build` = engineer, `/release` = release, `/aso` `/launch` = marketer. The hats' operating rules live in each stack's [`docs/PRINCIPLES.md`](react-native/docs/PRINCIPLES.md) § Role hats; each agent file mirrors its hat, so there's one source of truth.
- **`CLAUDE.md` is the always-loaded tax** — kept deliberately short (~55 lines). The full standing rules moved to `docs/PRINCIPLES.md`, loaded on demand.

## The workflow spine

```
/idea → /spec → /design → /build → /test → /release → /launch
```
It starts at the raw business idea: `/idea` pressure-tests it (GO / PIVOT / KILL) before any spec is written. Each phase's output feeds the next; don't skip. If a later phase finds an earlier one wrong, fix it at the source (re-`/spec` a bad requirement) — don't patch downstream. Full detail: `docs/WORKFLOWS.md`.

## Command cheat sheet (17 per stack)

- **Workflow:** `/idea` `/spec` `/design` `/build` `/test`* `/release`
- **Micro:** `/scope-check` `/bug` `/next` `/qa-sweep`* `/weekly-review`
- **Scaffold:** `/firestore` · `/hook` (RN) / `/provider` (Flutter) · `/track`
- **Release + marketing:** `/bump` `/aso` `/launch`

*`/test` and `/qa-sweep` are the only commands that spawn a sub-agent. Full index: `.claude/commands/README.md`.

## Standing rules (always on — full text in `docs/PRINCIPLES.md`)

1. **MVP-first.** v1 = minimum viable subset delivering the pillar outcomes. Default verdict on new scope: **CUT**.
2. **UX wins** every trade-off except MVP scope. Empty/loading/error/offline states ship with every feature.
3. **Analytics-first.** Every event is in `docs/TRACKING-PLAN.md` before code. No PII. Add via `/track`.
4. **QA gate.** No release with open P0/P1 bugs.
5. **Token discipline.** Prefer commands over re-typed prompts; no preambles/recaps; report file paths, not code dumps.

## Where things live (per stack)

```
CLAUDE.md              always-loaded constitution (lean)
docs/PRINCIPLES.md     standing rules + role "hats" (on-demand)
docs/WORKFLOWS.md      the 5-phase flow + 5 workflows
docs/PRD.md            pillars + feature specs (the scope gate)
docs/{TRACKING-PLAN,TEST-PLAN,RELEASE,LAUNCH,VERSIONING,SECURITY}.md
.claude/agents/        8 role agents (idea-validator → marketer; only qa-engineer spawns by default)
.claude/commands/      the 19 slash commands + README
design-systems/        3 swappable (notion-github, linear-minimal, warm-playful)
```
Flutter also has `docs/MASTER-SPEC.md` — pinned packages, idioms, gotchas; the engineer hat reads it before writing code.

## Gotchas

- **Mirror both stacks** for shared changes, or they drift.
- `docs/DESIGN.md` is **generated at setup**, not shipped — don't "fix" its absence in a bare scaffold.
- Firebase web config / `firebase_options.dart` is **not secret** — security is Firestore rules + Auth (+ App Check on Flutter). Real secrets: Admin service account, signing keys, OAuth secrets.
