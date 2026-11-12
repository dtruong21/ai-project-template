# Project templates — root

This repo holds **multiple project templates**, one subdirectory per stack. Each subdir is a fully self-contained scaffold for starting a new project in that stack — its own CLAUDE.md, agents, commands, docs, design systems, code scaffolding.

## Stacks

| Subdir | Stack | When to pick |
|---|---|---|
| [`react-native/`](react-native/) | React Native (Expo) + Firebase | JS ecosystem, EAS Build, Zustand + TanStack Query, NativeWind |
| [`flutter/`](flutter/) | Flutter + Firebase | Dart strict typing, Material 3, Riverpod, go_router, Codemagic |
| [`flutter-rust/`](flutter-rust/) | Flutter + Rust + Cloudflare (Workers, D1, R2); Firebase Auth/FCM only | Lowest run cost and footprint; shared Rust validation on app and API; no offline sync/realtime by default. Backend verified locally, bridge integration not yet — see its README status note |

All share the same workflow shape (`/idea → /spec → /design → /build → /test → /release → /launch`), the same 3 swappable design systems (`notion-github`, `linear-minimal`, `warm-playful`), and the same standing rules (MVP-first, UX priority, QA gate, analytics-first, token discipline).

## How to start a new project

```bash
./scripts/new-project.sh react-native ~/Documents/my-new-app
# or
./scripts/new-project.sh flutter ~/Documents/my-new-app
# or
./scripts/new-project.sh flutter-rust ~/Documents/my-new-app
```

The helper copies the chosen stack into the target dir, detaches the template's git history, and initializes a fresh repo. Then `cd ~/Documents/my-new-app && cat SETUP.md` and follow from Step 2.

## How to work on the templates themselves

You're here because you're improving the templates (not building a new project). Pick a stack:

```bash
cd react-native/   # or: cd flutter/  or: cd flutter-rust/
```

Inside the subdir, the full Claude Code setup is active — that subdir's `CLAUDE.md`, its 7-role agent roster in `.claude/agents/` (idea-validator, product-strategist, ux-designer, developer, qa-engineer, release-manager, marketer), its 17 slash commands (`.claude/commands/`), and its role "hats" in `docs/PRINCIPLES.md`. Most work runs in the main loop as a hat; only `/test` and `/qa-sweep` spawn a sub-agent by default — the rest of the roster is opt-in, for work big enough to isolate. This is tuned for Claude Pro usage limits. Work there.

If a change applies to ALL stacks (e.g. a sharpened command or role hat, a new standing rule, an additional edge-case in TEST-PLAN.md), **mirror it across every stack**. Otherwise they drift. `flutter-rust/` started as a copy of `flutter/`: everything except the data layer (`/d1`, `rust/`, `lib/core/api/`, SECURITY, SETUP Steps 5–7) should stay identical between the two.

## Adding a new stack

To add a third stack (e.g. `web/`, `electron/`, `swift/`) later:

1. Create the subdir with the same shape as the existing two (CLAUDE.md, SETUP.md, .claude/, design-systems/, docs/, lib/ or equivalent).
2. Add the stack to the table in this CLAUDE.md and in the root `README.md`.
3. Add the stack name to the `VALID` array in `scripts/new-project.sh`.

No central refactor needed — each stack stays isolated.

## What lives at the root (this directory)

- `CLAUDE.md` — this file, the index
- `README.md` — landing page on GitHub
- `DUAL-PC-WORKFLOW.md` — standing split of work across the two machines (Claude Code Pro build PC vs ChatGPT Go support PC)
- `LICENSE` — repo-wide
- `.gitignore` — cross-cutting ignores only; stack-specific ignores live in each subdir's `.gitignore`
- `scripts/new-project.sh` — the bootstrap helper
- `SETUP.md` — root setup notes (short — most setup is per-stack)
