# {{PROJECT_NAME}} — Claude constitution

Loaded every turn — kept tight on purpose. Full standing rules: `docs/PRINCIPLES.md`. Process: `docs/WORKFLOWS.md`. Spec: `docs/PRD.md`. Design: `docs/DESIGN.md`. Analytics: `docs/TRACKING-PLAN.md`. Flutter idioms/pins/gotchas: `docs/MASTER-SPEC.md`.

A React Native sibling template (same workflow, different stack) lives at `../react-native/` — cross-reference when a rule applies to both.

## Stack

- **App**: Flutter (SDK latest stable, pinned via `.fvmrc`), Dart + very_good_analysis, go_router
- **Backend**: Firebase — Auth, Firestore, Cloud Functions
- **State**: Riverpod (`@riverpod` codegen, AsyncNotifier) for local state + server cache
- **UI**: Material 3 `ThemeData`; tokens in `lib/core/design/tokens.dart`
- **Build**: Codemagic (CI), `flutter build` (local) · **Test**: flutter_test + integration_test + mocktail · **Validate**: freezed + json_serializable at Firestore boundaries

## Layout

```
lib/
  main.dart / app.dart / firebase_options.dart (generated, committed)
  core/firebase/    one repository per collection (typed .withConverter)
  core/design/      tokens.dart + theme.dart
  core/analytics/   client.dart + events.dart (typed registry)
  core/routing/     router.dart + routes.dart (typed go_router)
  features/<name>/  data / domain (freezed) / application (Riverpod) / presentation
test/               mirrors lib/ (unit + widget) · integration_test/ (E2E)
firebase/           firestore.rules (deployed) + functions/
docs/               specs, process, release
```

## Conventions (non-negotiable)

- Dart strict via `very_good_analysis`. No `dynamic` at boundaries — narrow with freezed + json_serializable.
- Firestore only via `lib/core/firebase/<collection>_repository.dart`. Never import `cloud_firestore` from feature code.
- Widgets are functions or `ConsumerWidget`. One screen = one widget in `features/<name>/presentation/`; logic in `application/`.
- `ref.watch` only in `build()`; inside notifier methods use `ref.read`.
- Server-set fields (`serverTimestamp`) are nullable in freezed models — `.withConverter` runs on optimistic snapshots.
- Tokens for all colors/spacing/type. No magic numbers. Tests mirror `lib/` under `test/`.

## How we work (Pro-optimized)

Routine work runs **in the main loop** via slash commands — no sub-agent spawn, no re-paid context tax. Spawn a sub-agent only when isolation genuinely pays: `/test` and `/qa-sweep` (the `qa-engineer` agent reads a lot) and wide multi-file searches (the built-in **Explore** agent). The full role roster also exists as **opt-in agents** in `.claude/agents/` (idea-validator → marketer) — spawn one only for big isolatable work; default is the hat.

Workflow: `/idea → /spec → /design → /build → /test → /release → /launch`. Each phase's output feeds the next; don't skip. If a later phase finds an earlier one wrong, fix it there. Product-owner steps: `/backlog` readies a spec'd story; `/accept` checks the build against its criteria before `/test`. Full process: `docs/WORKFLOWS.md`.

**Commands** — workflow: `/idea /spec /backlog /design /build /accept /test /release` · micro: `/scope-check /bug /next /qa-sweep /weekly-review` · scaffold: `/firestore /provider /track` · release+marketing: `/bump /aso /launch`. Index: `.claude/commands/README.md`. **Prefer commands over re-typing prompts.**

**Output discipline:** no preambles or end-of-turn recaps; report file paths, not code dumps; ask a cheap question before wide exploration; `Read` known paths, `Grep`/`Glob` for symbols — don't read whole folders.

## Standing rules (one line each — full text in `docs/PRINCIPLES.md`)

- **MVP-first.** v1 = the minimum viable subset delivering the pillar outcomes. Default verdict on new scope: **CUT**. `/scope-check` biases to cut.
- **UX wins** every trade-off except MVP scope: `MVP scope > UX > feature breadth > code elegance > dev convenience`. Empty / loading / error / offline states ship with every feature — every `AsyncValue` consumer renders `loading`/`error`/`data`.
- **Analytics-first.** Every event lives in `docs/TRACKING-PLAN.md` before code. No PII. Add via `/track`; fire via the typed registry in `lib/core/analytics/`.
- **QA gate.** No release with open P0/P1. See `.claude/agents/qa-engineer.md` + `docs/TEST-PLAN.md`.
- **Security.** `firebase_options.dart` is committed and not secret — rules + Auth + App Check are the model. Real secrets: Admin service account, Codemagic signing keys, OAuth secrets. `docs/SECURITY.md`.

## When stuck

Spec unclear → `/spec`. Design unclear → `/design`. Reuse unclear → `Grep` the symbol. Don't invent — ask.
