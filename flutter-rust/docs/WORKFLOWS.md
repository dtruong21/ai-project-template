# Workflows

How work moves from raw business idea to shipped and launched. One main loop.

## The model (Pro-optimized)

Each phase is a **hat you wear in the main loop** via a slash command — not a separate agent you spawn. Same conversation, same context, so you don't re-pay the context tax at every handoff. The one default exception is QA, which spawns the `qa-engineer` sub-agent (`/test`, `/qa-sweep`) because it reads a lot and isolation keeps that off the main thread. Wide multi-file searches go to the built-in **Explore** agent.

Every hat also exists as an **opt-in sub-agent** in `.claude/agents/` — spawn one only when the work is big enough to isolate (deep idea validation with web research, a whole-app design pass, a multi-feature build batch, a full launch-asset batch). Otherwise wear the hat.

```
/idea      strategist   →  validates it's worth building (GO/PIVOT/KILL)
/spec      strategist   →  defines what + why       (docs/PRD.md)
/design    designer     →  defines how it looks      (docs/DESIGN.md)
/build     engineer     →  implements + instruments  (code + tracked events)
/test      qa-engineer  →  verifies (code+analytics) [SUB-AGENT]
/release   release      →  ships the build via Codemagic
/launch    marketer     →  launches it to the world  (parallel from T-4w)
```

Each phase's output feeds the next. Don't skip. If a later phase finds an earlier one wrong, fix it at the source (re-`/spec` a bad requirement; re-`/design` a bad layout) — don't patch over it downstream. Hat operating rules live in `docs/PRINCIPLES.md § Role hats`.

---

## Workflow 0 — Idea validation

**Trigger:** a new business idea, before any PRD exists (project zero, or a pivot).

1. **Validate** — `/idea <the idea>`: problem, alternatives, wedge, monetization → verdict. For a deep market/competitor sweep, spawn the `idea-validator` agent instead (heavy web reads).
2. **KILL** → stop. Write nothing else; a dead idea is a cheap win.
3. **PIVOT** → reshape and re-run `/idea` on the sharper version.
4. **GO** → land `docs/PRD.md § Vision` + `§ Pillars` (max 3, each with a metric), then `/spec` the first pillar's features.

**Hard rule:** no `/spec` before a GO. Scope written for an unvalidated idea is scope you'll throw away.

---

## Workflow 1 — Feature development

**Trigger:** new feature idea, user request, or backlog item.

1. **Spec** — `/spec <name> — <idea>`. PRD entry: user story, acceptance criteria, edge cases, out of scope. Appended to `docs/PRD.md`. Bias to CUT.
2. **Design** — `/design <screen>`. Screen spec, widgets list, all states. Appended to `docs/DESIGN.md`. Mockup via Artifact only if the layout is non-obvious.
3. **Build** — `/build <feature>`. Data slice via `/d1` (migration → `rust/shared` model → Worker route → `rust/core` payload builder) → Riverpod provider → widget → route, in that order. Types everything (Rust structs at the API boundary, freezed for Dart view models). Runs codegen. Instruments analytics. Tests happy path on iOS Simulator + Android Emulator.
4. **QA** — `/test <feature>`. Spawns `qa-engineer`: widget tests for the provider + screen, edge-case sweep, bugs filed as `docs/bugs/<date>-<slug>.md`, test plan updated.
5. **Loop** until P0/P1 bugs are clear. Then mark the PRD entry `shipped` and move on.

**Hard rule:** don't start step N before step N-1 is done. New scope mid-build → run `/scope-check`, don't just absorb it.

---

## Workflow 2 — Bug fix

**Trigger:** bug reported (from QA, beta tester, production crash).

1. **Triage** — `/bug` (or `/qa-sweep` for a spawned pass): confirm repro, assign severity (P0–P3), file the report.
2. **Diagnose** — find root cause in the main loop. If it's a spec gap (bug exists because the requirement was ambiguous), re-`/spec` for a PRD clarification.
3. **Fix** — write the minimal fix + a regression test that would have caught it. **The regression test is the price of admission** — no fix ships without one.
4. **Verify** — `/test` (or `/qa-sweep`) confirms the original repro is dead and runs related edge cases.
5. **Close** — bug file moves to `docs/bugs/closed/`. If P0/P1, add an entry to the next release's CHANGELOG.

**Severity → urgency:** P0 = hotfix today · P1 = clear before next release · P2 = next release if cheap · P3 = backlog.

---

## Workflow 3 — Release

**Trigger:** milestone hit (all pillar-1 features shipping), or scheduled cadence (every 1–2 weeks).

1. **QA sign-off** — `/test` / `/qa-sweep` runs the full pre-release checklist (`docs/TEST-PLAN.md` + qa-engineer's pre-release section: `flutter analyze` clean, `flutter test` + `integration_test` green). No P0/P1 outstanding.
2. **Confirm the cut** — `/scope-check` anything half-built; feature-flag it off if it's not ready.
3. **Release** — `/release <staging|production>`: runs the checklist in `docs/RELEASE.md`, calls `/bump` (`version: X.Y.Z+N` in `pubspec.yaml`), tags the commit, prints the tag-push + `firebase deploy` commands.
4. **Build** — pushing the tag triggers the matching Codemagic workflow in `codemagic.yaml` (build + submit in one pass).
5. **Deploy the API** — `cargo test`, D1 migrations, then `wrangler deploy` to the target environment. API ships before the app build that needs it.
6. **Submit** — Codemagic publishing to TestFlight + Play Internal.
7. **Smoke test the build** — install the actual store artifact on a real device (not the simulator build) and run the golden path.
8. **Promote** — if `staging` validates over 2–3 days, promote to `production`.

**Rollback:** if `production` ships a P0, hotfix off the last good tag — don't unpublish. Flutter has no OTA; every fix is a full rebuild + store submission (Apple review is the long pole). Full procedure in `docs/PRINCIPLES.md § Release` and `docs/RELEASE.md`.

---

## Workflow 4 — Launch

**Trigger:** the release is live on TestFlight / Play Internal and ready for public discovery. Follows `docs/LAUNCH.md`.

1. **T-4w → T-2w (parallel with engineering)** — build the landing page, draft the initial store listing, open the waitlist.
2. **T-2w** — `/aso` against the latest PRD; update `docs/STORE_METADATA.md`.
3. **T-1w** — `/launch product-hunt`, `/launch tweet`, `/launch email` to draft assets. Review pass.
4. **T-0** — execute the launch-day checklist in `docs/LAUNCH.md`. Reply to every comment/DM within 1h.
5. **T+7d** — write the launch retro at `docs/postmortems/<date>-launch.md` (channels, NSM movement, v1.1 priorities).

**Hard rule:** don't launch to a cold list. The T-4w groundwork is non-negotiable.

---

## Workflow 5 — Design iteration

**Trigger:** a screen exists but feels wrong, or a new design token is needed.

1. `/design` proposes the change in `docs/DESIGN.md` (token diff + rationale).
2. If a token changes, `/build` updates `lib/core/design/tokens.dart` (and any `ThemeExtension` in `theme.dart`) and every widget consuming it.
3. `/qa-sweep` does a visual regression pass — every screen consuming the token, light + dark. Golden tests re-baselined if intentional.

---

## Cross-cutting practices

**Per session**
- **Use slash commands.** Each pre-fills context and runs in the main loop — the primary token-saving lever.
- Unsure where to pick up? `git status` + `/next` — a couple lines tell you the state.

**Daily**
- Update `docs/PRD.md` when scope shifts. A stale PRD is worse than none.
- Move closed bugs to `docs/bugs/closed/`. Don't let the active dir grow.

**Weekly (Monday)**
- `/weekly-review` — 15-min forcing function: stalled work, open P1s, roadmap drift, burnout risk. Lands in `docs/weekly-reviews/<date>.md`.
- Re-check `docs/ROADMAP.md` against actual progress; re-prioritize.
- `/qa-sweep` on `main`.
- Scan feedback (D1 `feedback` table — query in `lib/features/feedback/README.md`) — reply within 24h to anything substantive.

**Per release**
- CHANGELOG entry a non-technical user could understand.
- `/bump` the `version:` in `pubspec.yaml`; tag the commit.
- Smoke-test the store build on a real device.
