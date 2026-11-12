# Project templates

A family of opinionated scaffolds for solo-built mobile MVPs. One GitHub repo, one subdir per stack. Pick the stack — get a lean main-loop Claude Code workflow (a 7-role agent roster + 17 slash commands; roles run as main-loop "hats" by default, agents are opt-in), 3 swappable design systems, QA gate, tracking plan, launch playbook. Tuned for Claude Pro usage limits.

## Stacks shipped

| Stack | Subdir | Quick pitch |
|---|---|---|
| **React Native** (Expo + Firebase) | [`react-native/`](react-native/) | JavaScript ecosystem, EAS Build for cloud builds, Zustand + TanStack Query, NativeWind. Fast iteration. Largest community. |
| **Flutter** (Flutter + Firebase) | [`flutter/`](flutter/) | Dart strict typing, native compiled UI, Material 3, Riverpod with codegen, go_router, Codemagic. Stronger correctness guarantees. |

| **Flutter + Rust** (Flutter + Rust + Cloudflare) | [`flutter-rust/`](flutter-rust/) | Flutter UI, Rust logic shared between app and API, Cloudflare Workers + D1 + R2 backend, Firebase for Auth/push only. Lowest run cost; heavier toolchain. Backend verified locally; Flutter bridge integration not yet run end to end. |

All share the same workflow shape, design systems, and standing rules. Pick `react-native` or `flutter` by language/runtime preference — process is identical. Pick `flutter-rust` when run cost and footprint matter more than time-to-first-build (no offline sync or realtime out of the box).

## Quick start (new project)

```bash
# Once: clone this repo somewhere you can find it
git clone https://github.com/dtruong21/ai-project-template.git ~/Documents/templates

# Each new project: one command
~/Documents/templates/scripts/new-project.sh react-native ~/Documents/my-new-app
# or
~/Documents/templates/scripts/new-project.sh flutter ~/Documents/my-new-app
# or
~/Documents/templates/scripts/new-project.sh flutter-rust ~/Documents/my-new-app

# Then follow that project's SETUP.md
cd ~/Documents/my-new-app
cat SETUP.md
```

The helper copies the chosen stack, detaches the template's git history, and starts a fresh repo in the target directory.

## What every stack gives you

| Layer | What's in it |
|---|---|
| **Claude config** | 7-role agent roster (idea-validator → marketer) + 17 slash commands. Roles run in the main loop as "hats" (`docs/PRINCIPLES.md`) by default — only `qa-engineer` spawns automatically; the rest are opt-in for big isolatable work. Tuned for Claude Pro. |
| **Workflow** | Strict `/idea → /spec → /design → /build → /test → /release → /launch` pipeline, main-loop phases documented in `docs/WORKFLOWS.md` |
| **Design system family** | 3 swappable: `notion-github`, `linear-minimal`, `warm-playful`. Pick one per project via `scripts/pick-design-system.sh`. |
| **Analytics layer** | Tracking plan + typed event registry (TS for RN / Dart sealed class for Flutter) + provider-agnostic client. |
| **Feedback loop** | In-app feedback feature scaffold + Firestore pattern + `feedback_submitted` event. |
| **Launch playbook** | Marketer hat + `docs/LAUNCH.md` runbook + `/aso` + `/launch <channel>`. |
| **Solo-dev forcing functions** | `/weekly-review` Monday checkpoint, MVP-first defaults, burnout flagging. |
| **QA gate** | Severity rubric, universal edge-case checklist, bug templates, pre-release gate. |
| **Docs scaffolding** | PRD, ROADMAP, WORKFLOWS, TRACKING-PLAN, TEST-PLAN, RELEASE, LAUNCH, SECURITY, STORE_METADATA, legal templates. |

## Standing rules (baked into every project)

1. **v1 is an MVP.** Default verdict on new scope is POST-MVP. Make me argue features INTO v1.
2. **UX is the top priority** — wins every trade-off except MVP scope. States (empty/loading/error/offline) are first-class.
3. **QA gates releases.** No release ships with open P0/P1 bugs. Every fix ships with a regression test.
4. **Analytics-first.** Tracking plan precedes code. Events are typed. No PII as properties.
5. **Token discipline.** Commands run in the main loop as role "hats" (no per-phase sub-agent spawn); pre-filled prompts keep responses tight. Tuned for Claude Pro usage limits.

## File layout (this repo)

```
.
├── CLAUDE.md                 root index (thin)
├── README.md                 this file
├── SETUP.md                  short — most setup is per-stack
├── DUAL-PC-WORKFLOW.md       Claude Code PC vs ChatGPT Go PC — task routing + git protocol
├── LICENSE
├── .gitignore                cross-cutting only
├── scripts/
│   └── new-project.sh        bootstrap helper
├── react-native/             full React Native template
│   ├── CLAUDE.md             RN constitution
│   ├── SETUP.md              RN bootstrap (10 steps)
│   ├── .claude/              7 role agents + 17 commands
│   ├── design-systems/       3 swappable
│   ├── docs/                 PRD, ROADMAP, etc.
│   ├── lib/                  analytics + features scaffold
│   └── ...
└── flutter/                  full Flutter template
    ├── CLAUDE.md             Flutter constitution
    ├── SETUP.md              Flutter bootstrap (10 steps)
    ├── docs/MASTER-SPEC.md   pinned packages, idioms, gotchas
    ├── .claude/
    ├── design-systems/
    ├── docs/
    ├── lib/                  Dart scaffolding (analytics + features + firebase + routing)
    └── ...
```

## Improving the templates

You're in this repo because you want to make a template better. Pick a stack:

```bash
cd react-native/   # or: cd flutter/
```

Inside the subdir, Claude Code picks up that stack's CLAUDE.md and tooling. Make the change there. When you `git push`, the change is available for every future new project.

If a change applies to BOTH stacks (a sharper standing rule, a new shared edge-case, etc.), mirror it across both. The two templates drift otherwise.

## Adding a new stack

Want a third stack (web, electron, swift)? Add a sibling subdir with the same shape — its own CLAUDE.md, SETUP.md, `.claude/`, etc. Then add it to the table in this README, the table in root `CLAUDE.md`, and the `VALID` array in `scripts/new-project.sh`. No central refactor — each stack is isolated.

## License

See [LICENSE](LICENSE).
